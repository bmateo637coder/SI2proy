import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'dart:convert';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/secure_storage_service.dart';
import '../../data/services/offline_identity.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(
    this._repository,
    this._storage, {
    OfflineIdentity? offlineIdentity,
  }) : _offlineIdentity = offlineIdentity ?? OfflineIdentity();
  final OfflineIdentity _offlineIdentity;
  bool needsOnlineLogin = false;
  Future<void> sessionExpired() async {
    needsOnlineLogin = true;
    localSession = true;
    notifyListeners();
  }

  Future<void> validateServerProfile(Map<String, dynamic> value) async {
    final verified = UserModel.fromJson(value);
    if (_user == null || verified.ci != _user!.ci)
      throw StateError('La identidad del servidor no corresponde a la sesión.');
    final changed =
        jsonEncode(verified.toJson()) != jsonEncode(_user!.toJson());
    _user = verified;
    await _storage.saveProfile(jsonEncode(verified.toJson()));
    if (changed) {
      await _restoreScope();
      onScopeChanged?.call();
    }
    await _offlineIdentity.refreshProfile(
      verified.email,
      verified.toJson(),
      companies,
    );
    if (changed || localSession) {
      localSession = false;
      notifyListeners();
    }
  }

  final AuthRepository _repository;
  final SecureStorageService _storage;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  int? selectedTenant;
  List<Map<String, dynamic>> companies = [];
  String? companyError;
  bool localSession = false;
  VoidCallback? onScopeChanged;
  bool get isSuperAdmin => _user?.idRol == 1;
  bool get allTenants => isSuperAdmin && selectedTenant == 0;
  String get scopeKey =>
      '${_user?.ci}|${isSuperAdmin ? selectedTenant : _user?.idTenant}';
  UserModel? get operationUser => isSuperAdmin && (selectedTenant ?? 0) > 0
      ? _user?.forTenant(selectedTenant!)
      : _user;
  bool get canWrite => !allTenants && (operationUser?.idTenant ?? 0) > 0;
  String get scopeLabel => allTenants
      ? 'Todas las inmobiliarias'
      : companies
                .where((c) => c['id_tenant'] == selectedTenant)
                .map((c) => c['nombre'].toString())
                .firstOrNull ??
            'Inmobiliaria ${selectedTenant ?? _user?.idTenant ?? "sin seleccionar"}';

  Future<void> loadCompanies({bool notify = true}) async {
    if (!isSuperAdmin) return;
    companyError = null;
    try {
      companies = await _repository.companies();
      await _storage.saveCompanies(jsonEncode(companies));
    } catch (_) {
      companyError = 'No se pudo actualizar la lista. Se muestran las inmobiliarias guardadas.';
    }
    if (notify) notifyListeners();
  }

  Future<void> _restoreScope() async {
    final stored = await _storage.readTenantId();
    selectedTenant = isSuperAdmin
        ? (stored == 'all' ? 0 : int.tryParse(stored ?? '') ?? 0)
        : _user?.idTenant;
    final cached = await _storage.readCompanies();
    if (isSuperAdmin && cached != null) {
      try {
        companies = (jsonDecode(cached) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } catch (_) {
        companies = [];
      }
    }
    await _storage.saveTenantId(
      isSuperAdmin && selectedTenant == 0 ? 'all' : '${selectedTenant ?? ""}',
    );
  }

  Future<void> selectTenant(int id) async {
    if (!isSuperAdmin ||
        (id != 0 && !companies.any((c) => c['id_tenant'] == id)))
      return;
    await _storage.saveTenantId(id == 0 ? 'all' : '$id');
    selectedTenant = id;
    onScopeChanged?.call();
    notifyListeners();
  }

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> restoreSession() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) return;
    try {
      _user = await _repository.getMe();
      if (_user != null) {
        await _storage.saveProfile(jsonEncode(_user!.toJson()));
      }
      if (_user != null && _user!.idTenant > 0) {
        await _storage.saveTenantId(_user!.idTenant.toString());
      }
      await _restoreScope();
      localSession = false;
      needsOnlineLogin = false;
      if (isSuperAdmin) await loadCompanies();
      notifyListeners();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        await signOut(notify: false);
      } else {
        final cached = await _storage.readProfile();
        if (cached != null) {
          try {
            _user = UserModel.fromJson(
              jsonDecode(cached) as Map<String, dynamic>,
            );
            await _restoreScope();
            localSession = true;
          } catch (_) {
            _user = null;
          }
        }
        notifyListeners();
      }
    }
  }

  Future<bool> signIn(String email, String password) async {
    _user = null;
    _setLoading(true);
    _errorMessage = null;
    try {
      await _storage.clear();
      final tokens = await _repository.login(email, password);
      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      UserModel? profile;
      try {
        profile = await _repository.getMe();
        if (profile.idTenant > 0) {
          await _storage.saveTenantId(profile.idTenant.toString());
        }
      } on DioException {
        // El login fue exitoso pero el perfil no pudo cargarse.
        profile = tokens.user;
        if (profile.idTenant > 0) {
          await _storage.saveTenantId(profile.idTenant.toString());
        }
      }
      _user = profile;
      if (_user == null || _user!.ci.isEmpty || _user!.idRol <= 0) {
        throw StateError(
          'No se pudo verificar el perfil. Reintenta iniciar sesión.',
        );
      }
      if (_user != null) {
        await _storage.saveProfile(jsonEncode(_user!.toJson()));
      }
      await _restoreScope();
      localSession = false;
      if (isSuperAdmin) await loadCompanies(notify: false);
      needsOnlineLogin = false;
      await _offlineIdentity.remember(
        email,
        password,
        _user!.toJson(),
        tokens.accessToken,
        companies,
      );
      onScopeChanged?.call();
      return _user != null;
    } catch (error) {
      if (error is DioException &&
          (error.response == null ||
              (error.response!.statusCode ?? 0) >= 500)) {
        try {
          final saved = await _offlineIdentity.unlock(email, password);
          if (saved == null)
            throw StateError(
              'Acceso local no disponible o contraseña incorrecta. Inicia sesión una vez con Internet.',
            );
          _user = UserModel.fromJson(
            Map<String, dynamic>.from(saved['profile']),
          );
          companies = (saved['companies'] as List)
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
          await _storage.saveTokens(
            accessToken: saved['token'],
            refreshToken: '',
          );
          await _storage.saveProfile(jsonEncode(saved['profile']));
          await _storage.saveCompanies(jsonEncode(companies));
          await _restoreScope();
          localSession = true;
          needsOnlineLogin = false;
          onScopeChanged?.call();
          return true;
        } catch (localError) {
          _errorMessage = localError is StateError
              ? '${localError.message}'
              : 'No se pudo verificar el acceso local.';
          _user = null;
          await _storage.clear();
          return false;
        }
      }
      if (error is DioException &&
          [401, 403].contains(error.response?.statusCode))
        await _offlineIdentity.revoke(email);
      _user = null;
      await _storage.clear();
      if (error is DioException) {
        _errorMessage = _apiError(error, 'No se pudo iniciar sesión.');
      } else {
        _errorMessage = 'Error local: $error';
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String ci,
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _repository.register(
        ci: ci,
        nombre: nombre,
        correo: correo,
        telefono: telefono,
        password: password,
      );
      // Tras registro exitoso, se intenta loguear.
      return await signIn(correo, password);
    } catch (error) {
      if (error is DioException) {
        _errorMessage = _apiError(error, 'No se pudo registrar la cuenta.');
      } else {
        _errorMessage = 'Error local: $error';
      }
      _setLoading(
        false,
      ); // set false si falla (signIn ya lo hace si es exitoso)
      return false;
    }
  }

  Future<void> signOut({bool notify = true}) async {
    await _storage.clear();
    _user = null;
    selectedTenant = null;
    companies = [];
    localSession = false;
    needsOnlineLogin = false;
    onScopeChanged?.call();
    if (notify) notifyListeners();
  }

  /// CU-03: Solicita la recuperación de contraseña.
  /// Devuelve el mensaje informativo del servidor, o '' si falla.
  Future<String> forgotPassword(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      return await _repository.forgotPassword(email.trim());
    } catch (error) {
      _errorMessage = error is DioException
          ? _apiError(error, 'No se pudo procesar la solicitud.')
          : 'Error local: $error';
      return '';
    } finally {
      _setLoading(false);
    }
  }

  /// CU-04: Cambia la contraseña del usuario autenticado.
  Future<bool> changePassword(String newPassword) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _repository.changePassword(newPassword);
      await _offlineIdentity.revoke(_user!.email);
      return true;
    } catch (error) {
      _errorMessage = error is DioException
          ? _apiError(error, 'No se pudo cambiar la contraseña.')
          : 'Error local: $error';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  String _apiError(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return fallback;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

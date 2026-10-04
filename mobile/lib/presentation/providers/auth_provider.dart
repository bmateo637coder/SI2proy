import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/secure_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository, this._storage);

  final AuthRepository _repository;
  final SecureStorageService _storage;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> restoreSession() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) return;
    try {
      _user = await _repository.getMe();
      notifyListeners();
    } on DioException {
      await signOut(notify: false);
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final tokens = await _repository.login(email, password);
      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      UserModel? profile;
      try {
        profile = await _repository.getMe();
      } on DioException {
        // El login fue exitoso pero el perfil no pudo cargarse.
        profile = tokens.user;
      }
      _user = profile;
      return _user != null;
    } catch (error) {
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

  Future<void> signOut({bool notify = true}) async {
    await _storage.clear();
    _user = null;
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
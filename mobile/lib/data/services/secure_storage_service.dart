import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tenantIdKey = 'tenant_id';
  static const _profileKey = 'offline_profile';
  static const _companiesKey = 'companies_cache';
  final FlutterSecureStorage _storage;

  // In-memory fallback for web over HTTP where WebCrypto is not available
  final Map<String, String> _webFallback = {};

  Future<String?> readAccessToken() async {
    if (kIsWeb) return _webFallback[_accessTokenKey];
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() async {
    if (kIsWeb) return _webFallback[_refreshTokenKey];
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (kIsWeb) {
      _webFallback[_accessTokenKey] = accessToken;
      _webFallback[_refreshTokenKey] = refreshToken;
    } else {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      _webFallback.clear();
    } else {
      for (final key in [_accessTokenKey, _refreshTokenKey, _tenantIdKey, _profileKey, _companiesKey]) {
        await _storage.delete(key: key);
      }
    }
  }

  Future<String?> readTenantId() async {
    if (kIsWeb) return _webFallback[_tenantIdKey];
    return await _storage.read(key: _tenantIdKey);
  }

  Future<void> saveTenantId(String tenantId) async {
    if (kIsWeb) {
      _webFallback[_tenantIdKey] = tenantId;
    } else {
      await _storage.write(key: _tenantIdKey, value: tenantId);
    }
  }

  Future<void> saveProfile(String profile) async {
    if (kIsWeb) {
      _webFallback[_profileKey] = profile;
    } else {
      await _storage.write(key: _profileKey, value: profile);
    }
  }

  Future<String?> readProfile() async {
    return kIsWeb ? _webFallback[_profileKey] : _storage.read(key: _profileKey);
  }

  Future<void> saveCompanies(String value) async {
    if (kIsWeb) {
      _webFallback[_companiesKey] = value;
    } else {
      await _storage.write(key: _companiesKey, value: value);
    }
  }

  Future<String?> readCompanies() async =>
      kIsWeb ? _webFallback[_companiesKey] : _storage.read(key: _companiesKey);
}

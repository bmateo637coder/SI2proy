import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
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
      await _storage.deleteAll();
    }
  }
}
import 'package:dio/dio.dart';

import '../services/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._onUnauthorized);

  final SecureStorageService _storage;
  final Future<void> Function() _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    if (err.response?.statusCode == 401 &&
      !path.contains('/login') &&
      !path.contains('/auth/logout')) {
      await _onUnauthorized();
    }
    handler.next(err);
  }
}
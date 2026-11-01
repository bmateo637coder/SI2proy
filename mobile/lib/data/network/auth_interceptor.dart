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
    if (token != null && token.isNotEmpty && options.path != '/login') {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers.remove('X-Tenant-ID');
    options.headers.remove('X-Tenant-Scope');
    if (!options.path.startsWith('/users/me') && options.path != '/login') {
      final tenant =
          options.extra['tenantId']?.toString() ??
          await _storage.readTenantId();
      if (tenant == 'all') {
        options.headers['X-Tenant-Scope'] = 'all';
      } else if (int.tryParse(tenant ?? '') case final int value
          when value > 0) {
        options.headers['X-Tenant-ID'] = value.toString();
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final path = err.requestOptions.path;
    if (err.response?.statusCode == 401 &&
        !path.contains('/login') &&
        !path.contains('/auth/logout')) {
      await _onUnauthorized();
    }
    handler.next(err);
  }
}

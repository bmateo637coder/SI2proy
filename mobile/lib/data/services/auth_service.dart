import 'package:dio/dio.dart';

import '../models/token_response_model.dart';
import '../models/user_model.dart';

class AuthService {
  const AuthService(this._dio);

  final Dio _dio;

  Future<TokenResponseModel> login(String email, String password) async {
    final response = await _dio.post('/login', data: {
      'correo': email,
      'password': password,
    });
    return TokenResponseModel.fromJson(
      response.data as Map<String, dynamic>,
      fallbackEmail: email,
    );
  }

  Future<UserModel> getMe() async {
    final response = await _dio.get('/users/me');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> forgotPassword(String email) async {
    final response = await _dio.post('/forgot-password', data: {'correo': email});
    return (response.data as Map<String, dynamic>)['message'] as String? ?? 'Si el correo existe, se han enviado las instrucciones de recuperación.';
  }

  Future<void> changePassword(String newPassword) async {
    await _dio.put('/users/me/password', data: {
      'nueva_password': newPassword,
    });
  }
}
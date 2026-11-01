import 'package:dio/dio.dart';

import '../models/token_response_model.dart';
import '../models/user_model.dart';

class AuthService {
  const AuthService(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> companies() async {
    final response = await _dio.get<List<dynamic>>('/admin/empresas');
    return response.data!
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<TokenResponseModel> login(String email, String password) async {
    final response = await _dio.post(
      '/login',
      data: {'correo': email, 'password': password},
    );
    return TokenResponseModel.fromJson(
      response.data as Map<String, dynamic>,
      fallbackEmail: email,
    );
  }

  Future<void> register({
    required String ci,
    required String nombre,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    await _dio.post(
      '/gestion_usuarios/auth/register',
      data: {
        'ci': ci,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'id_rol': 3, // 3 = Cliente
        'id_tenant': 1, // 1 = Metropoli Bienes Raíces (por defecto)
        'password': password,
      },
    );
  }

  Future<UserModel> getMe() async {
    final response = await _dio.get('/users/me');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> forgotPassword(String email) async {
    final response = await _dio.post(
      '/forgot-password',
      data: {'correo': email},
    );
    return (response.data as Map<String, dynamic>)['message'] as String? ??
        'Si el correo existe, se han enviado las instrucciones de recuperación.';
  }

  Future<void> changePassword(String newPassword) async {
    await _dio.put('/users/me/password', data: {'nueva_password': newPassword});
  }
}

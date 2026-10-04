import '../models/token_response_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthRepository {
  const AuthRepository(this._service);

  final AuthService _service;

  Future<TokenResponseModel> login(String email, String password) =>
      _service.login(email, password);
  Future<UserModel> getMe() => _service.getMe();
  Future<String> forgotPassword(String email) => _service.forgotPassword(email);
  Future<void> changePassword(String newPassword) =>
      _service.changePassword(newPassword);
}
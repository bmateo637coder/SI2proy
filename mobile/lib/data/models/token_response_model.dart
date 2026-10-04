import 'user_model.dart';

class TokenResponseModel {
  const TokenResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final UserModel user;

  factory TokenResponseModel.fromJson(
    Map<String, dynamic> json, {
    String? fallbackEmail,
  }) =>
      TokenResponseModel(
        accessToken: json['access_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
        tokenType: json['token_type'] as String? ?? 'bearer',
        user: json['user'] is Map
            ? UserModel.fromJson((json['user'] as Map).cast<String, dynamic>())
            : UserModel(
                id: 0,
                ci: '',
                email: fallbackEmail ?? '',
                fullName: 'Usuario autenticado',
                telefono: '',
                idTenant: 0,
                idRol: 0,
                isActive: true,
                permisos: const [],
                roles: const [],
              ),
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        'user': user.toJson(),
      };
}
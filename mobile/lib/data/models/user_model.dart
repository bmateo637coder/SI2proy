class RoleModel {
  const RoleModel({
    required this.id,
    required this.name,
    required this.permissions,
  });

  final int id;
  final String name;
  final List<String> permissions;

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        permissions: (json['permissions'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'permissions': permissions,
      };
}

class UserModel {
  const UserModel({
    required this.id,
    required this.ci,
    required this.email,
    required this.fullName,
    required this.telefono,
    required this.idTenant,
    required this.idRol,
    required this.isActive,
    required this.permisos,
    required this.roles,
  });

  final int id;
  final String ci;
  final String email;
  final String fullName;
  final String telefono;
  final int idTenant;
  final int idRol;
  final bool isActive;
  final List<String> permisos;
  final List<RoleModel> roles;

  bool hasPermission(String codigo) => permisos.contains(codigo);

  bool get isAdministrator => idRol == 1 || idRol == 2;

  bool get canSeeClientes =>
      isAdministrator || permisos.contains('UI:MENU_CLIENTES');

  bool get canSeeContratos =>
      isAdministrator || permisos.contains('UI:MENU_PROPIEDADES');

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RoleModel.fromJson)
        .toList();
    return UserModel(
      id: roles.isNotEmpty
          ? roles.first.id
          : (json['id'] as num?)?.toInt() ?? 0,
      ci: json['ci'] as String? ?? '',
      email: (json['correo'] ?? json['email']) as String? ?? '',
      fullName: (json['nombre'] ?? json['full_name']) as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      idTenant: (json['id_tenant'] as num?)?.toInt() ?? 0,
      idRol: (json['id_rol'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      permisos: (json['permisos'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ci': ci,
        'email': email,
        'full_name': fullName,
        'telefono': telefono,
        'id_tenant': idTenant,
        'id_rol': idRol,
        'is_active': isActive,
        'permisos': permisos,
        'roles': roles.map((role) => role.toJson()).toList(),
      };
}
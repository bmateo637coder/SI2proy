class ClienteModel {
  const ClienteModel({
    required this.idCliente,
    required this.ciUsuario,
    required this.idTenant,
    required this.nombre,
    required this.correo,
    required this.telefono,
  });

  final int idCliente;
  final String ciUsuario;
  final int idTenant;
  final String nombre;
  final String correo;
  final String telefono;

  factory ClienteModel.fromJson(Map<String, dynamic> json) => ClienteModel(
        idCliente: json['id_cliente'] as int? ?? 0,
        ciUsuario: json['ci_usuario'] as String? ?? '',
        idTenant: json['id_tenant'] as int? ?? 0,
        nombre: json['nombre'] as String? ?? '',
        correo: json['correo'] as String? ?? '',
        telefono: json['telefono'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id_cliente': idCliente,
        'ci_usuario': ciUsuario,
        'id_tenant': idTenant,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
      };
}
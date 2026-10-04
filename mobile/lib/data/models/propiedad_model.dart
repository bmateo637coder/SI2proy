class ImagenModel {
  const ImagenModel({
    required this.idImagen,
    required this.url,
  });

  final int idImagen;
  final String url;

  factory ImagenModel.fromJson(Map<String, dynamic> json) => ImagenModel(
        idImagen: json['id_imagen'] as int? ?? 0,
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id_imagen': idImagen,
        'url': url,
      };
}

class PropiedadModel {
  const PropiedadModel({
    required this.idPropiedad,
    required this.idTenant,
    required this.idPropietario,
    required this.idAgente,
    required this.titulo,
    required this.direccion,
    required this.precio,
    required this.tipoOperacion,
    required this.estado,
    required this.imagenes,
  });

  final int idPropiedad;
  final int idTenant;
  final int idPropietario;
  final int idAgente;
  final String titulo;
  final String direccion;
  final double precio;
  final String tipoOperacion;
  final String estado;
  final List<ImagenModel> imagenes;

  factory PropiedadModel.fromJson(Map<String, dynamic> json) => PropiedadModel(
        idPropiedad: json['id_propiedad'] as int? ?? 0,
        idTenant: json['id_tenant'] as int? ?? 0,
        idPropietario: json['id_propietario'] as int? ?? 0,
        idAgente: json['id_agente'] as int? ?? 0,
        titulo: json['titulo'] as String? ?? '',
        direccion: json['direccion'] as String? ?? '',
        precio: json['precio'] != null
            ? double.tryParse(json['precio'].toString()) ?? 0.0
            : 0.0,
        tipoOperacion: json['tipo_operacion'] as String? ?? '',
        estado: json['estado'] as String? ?? '',
        imagenes: (json['imagenes'] as List<dynamic>?)
                ?.map((e) => ImagenModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'id_propiedad': idPropiedad,
        'id_tenant': idTenant,
        'id_propietario': idPropietario,
        'id_agente': idAgente,
        'titulo': titulo,
        'direccion': direccion,
        'precio': precio,
        'tipo_operacion': tipoOperacion,
        'estado': estado,
        'imagenes': imagenes.map((e) => e.toJson()).toList(),
      };
}

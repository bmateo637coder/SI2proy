import 'package:dio/dio.dart';
import '../models/propiedad_model.dart';

class PropiedadesService {
  const PropiedadesService(this._dio);

  final Dio _dio;

  Future<List<PropiedadModel>> getPropiedades() async {
    final response = await _dio.get('/modulo_inmuebles/propiedades');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((json) => PropiedadModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

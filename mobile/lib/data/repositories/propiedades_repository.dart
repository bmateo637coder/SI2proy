import '../models/propiedad_model.dart';
import '../services/propiedades_service.dart';

class PropiedadesRepository {
  const PropiedadesRepository(this._service);

  final PropiedadesService _service;

  Future<List<PropiedadModel>> getPropiedades() async {
    try {
      return await _service.getPropiedades();
    } catch (e) {
      throw Exception('Error al cargar propiedades: $e');
    }
  }
}

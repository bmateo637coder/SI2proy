import '../models/cliente_model.dart';
import '../services/clientes_service.dart';

class ClientesRepository {
  const ClientesRepository(this._service);

  final ClientesService _service;

  Future<List<ClienteModel>> getClientes() async {
    try {
      return await _service.getClientes();
    } catch (e) {
      throw Exception('Error al cargar clientes: $e');
    }
  }

  Future<ClienteModel> createCliente(String ciUsuario) async {
    try {
      return await _service.createCliente(ciUsuario);
    } catch (e) {
      throw Exception('Error al registrar cliente: $e');
    }
  }
}
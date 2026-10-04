import 'package:dio/dio.dart';
import '../models/cliente_model.dart';

class ClientesService {
  const ClientesService(this._dio);

  final Dio _dio;

  Future<List<ClienteModel>> getClientes() async {
    final response = await _dio.get('/modulo_inmuebles/clientes');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((json) => ClienteModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ClienteModel> createCliente(String ciUsuario) async {
    final response = await _dio.post('/modulo_inmuebles/clientes', data: {
      'ci_usuario': ciUsuario,
    });
    return ClienteModel.fromJson(response.data as Map<String, dynamic>);
  }
}
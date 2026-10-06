import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../models/contrato_model.dart';

class ContratosService {
  const ContratosService(this._dio);

  final Dio _dio;

  Future<List<ContratoModel>> getContratos() async {
    final response = await _dio.get('/gestion_contractual/contratos');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((json) => ContratoModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ContratoModel> getContratoDetalle(int idContrato) async {
    final response = await _dio
        .get('/gestion_contractual/contratos/$idContrato');
    return ContratoModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContratoModel> createContrato({
    required int idCliente,
    required int idPropiedad,
    required String tipoContrato,
    required double montoTotal,
    required String fechaInicio,
    String? fechaFin,
    int? numCuotas,
  }) async {
    final data = <String, dynamic>{
      'id_cliente': idCliente,
      'id_propiedad': idPropiedad,
      'tipo_contrato': tipoContrato,
      'monto_total': montoTotal,
      'fecha_inicio': fechaInicio,
      if (fechaFin != null && fechaFin.isNotEmpty) 'fecha_fin': fechaFin,
      if (numCuotas != null && numCuotas > 0) 'num_cuotas': numCuotas,
    };
    final response = await _dio.post('/gestion_contractual/contratos', data: data);
    return ContratoModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> registrarPago({
    required int idContrato,
    required double monto,
    required String metodoPago,
  }) async {
    final response = await _dio.post(
      '/gestion_contractual/contratos/$idContrato/pagos',
      data: {'monto': monto, 'metodo_pago': metodoPago},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> eliminarContrato(int idContrato) async {
    await _dio.delete('/gestion_contractual/contratos/$idContrato');
  }

  Future<Uint8List> descargarComprobante(int idPago) async {
    final response = await _dio.get<Uint8List>(
      '/gestion_contractual/pagos/$idPago/comprobante',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? Uint8List(0);
  }
}
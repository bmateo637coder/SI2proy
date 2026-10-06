import 'dart:typed_data';

import '../models/contrato_model.dart';
import '../services/contratos_service.dart';

class ContratosRepository {
  const ContratosRepository(this._service);

  final ContratosService _service;

  Future<List<ContratoModel>> getContratos() async {
    try {
      return await _service.getContratos();
    } catch (e) {
      throw Exception('Error al cargar contratos: $e');
    }
  }

  Future<ContratoModel> getContratoDetalle(int idContrato) async {
    try {
      return await _service.getContratoDetalle(idContrato);
    } catch (e) {
      throw Exception('Error al abrir contrato: $e');
    }
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
    try {
      return await _service.createContrato(
        idCliente: idCliente,
        idPropiedad: idPropiedad,
        tipoContrato: tipoContrato,
        montoTotal: montoTotal,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        numCuotas: numCuotas,
      );
    } catch (e) {
      throw Exception('Error al crear contrato: $e');
    }
  }

  Future<Map<String, dynamic>> registrarPago({
    required int idContrato,
    required double monto,
    required String metodoPago,
  }) async {
    try {
      return await _service.registrarPago(
        idContrato: idContrato,
        monto: monto,
        metodoPago: metodoPago,
      );
    } catch (e) {
      throw Exception('Error al registrar pago: $e');
    }
  }

  Future<void> eliminarContrato(int idContrato) async {
    try {
      await _service.eliminarContrato(idContrato);
    } catch (e) {
      throw Exception('Error al eliminar contrato: $e');
    }
  }

  Future<Uint8List> descargarComprobante(int idPago) async {
    try {
      return await _service.descargarComprobante(idPago);
    } catch (e) {
      throw Exception('Error al descargar comprobante: $e');
    }
  }
}
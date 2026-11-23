import 'package:flutter/foundation.dart';

import '../../data/services/api_error.dart';
import '../../data/models/contrato_model.dart';
import '../../data/repositories/contratos_repository.dart';

class ContratosProvider extends ChangeNotifier {
  ContratosProvider(this._repository);

  final ContratosRepository _repository;
  int _generation = 0;
  int _listRequest = 0;
  int _detailRequest = 0;
  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  void reset() {
    _generation++;
    _isSubmitting = false;
    _isDownloadingComprobante = false;
    _contratos = [];
    _listLoading = false;
    _detailLoading = false;
    _errorMessage = null;
    _detalle = null;
    _successMessage = null;
    notifyListeners();
  }

  List<ContratoModel> _contratos = [];
  List<ContratoModel> get contratos => _contratos;

  ContratoModel? _detalle;
  ContratoModel? get detalle => _detalle;

  bool _listLoading = false, _detailLoading = false;
  bool get isLoading => _listLoading || _detailLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  bool _isDownloadingComprobante = false;
  bool get isDownloadingComprobante => _isDownloadingComprobante;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  Future<void> fetchContratos() async {
    final generation = _generation;
    final request = ++_listRequest;
    _listLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getContratos();
      if (generation != _generation || request != _listRequest) return;
      _contratos = result;
    } catch (e) {
      if (generation != _generation || request != _listRequest) return;
      _errorMessage = apiError(e);
    } finally {
      if (generation == _generation && request == _listRequest) {
        _listLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchDetalle(int idContrato) async {
    final generation = _generation;
    final request = ++_detailRequest;
    _detalle = null;
    _detailLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getContratoDetalle(idContrato);
      if (generation != _generation || request != _detailRequest) return;
      _detalle = result;
    } catch (e) {
      if (generation != _generation || request != _detailRequest) return;
      _errorMessage = apiError(e);
    } finally {
      if (generation == _generation && request == _detailRequest) {
        _detailLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createContrato({
    required int idCliente,
    required int idPropiedad,
    required String tipoContrato,
    required double montoTotal,
    required String fechaInicio,
    String? fechaFin,
    int? numCuotas,
    bool aplicarPromocion = false,
  }) async {
    final generation = _generation;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final creado = await _repository.createContrato(
        idCliente: idCliente,
        idPropiedad: idPropiedad,
        tipoContrato: tipoContrato,
        montoTotal: montoTotal,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        numCuotas: numCuotas,
        aplicarPromocion: aplicarPromocion,
      );
      if (generation != _generation) return false;
      _contratos = [..._contratos, creado];
      _successMessage = creado.pendienteSync
          ? 'Contrato guardado en el teléfono. Pendiente de sincronizar.'
          : 'Contrato #${creado.idContrato} creado correctamente.';
      return true;
    } catch (e) {
      if (generation == _generation) _errorMessage = apiError(e);
      return false;
    } finally {
      if (generation == _generation) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  Future<String?> registrarPago({
    required int idContrato,
    required double monto,
    required String metodoPago,
  }) async {
    final generation = _generation;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.registrarPago(
        idContrato: idContrato,
        monto: monto,
        metodoPago: metodoPago,
      );
      if (generation != _generation) return null;
      final recibo = result['numero_recibo'] as String? ?? '';
      _successMessage = result['pendiente_sync'] == true
          ? 'Pago guardado en el teléfono. Recibo provisional: $recibo. Pendiente de sincronizar.'
          : 'Pago registrado. Recibo: $recibo';
      await fetchDetalle(idContrato);
      if (generation != _generation) return null;
      await fetchContratos();
      if (generation != _generation) return null;
      return recibo;
    } catch (e) {
      if (generation == _generation) _errorMessage = apiError(e);
      return null;
    } finally {
      if (generation == _generation) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  Future<bool> eliminarContrato(int idContrato) async {
    final generation = _generation;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.eliminarContrato(idContrato);
      if (generation != _generation) return false;
      _contratos = _contratos.where((c) => c.idContrato != idContrato).toList();
      _successMessage = 'Contrato eliminado.';
      return true;
    } catch (e) {
      if (generation == _generation) _errorMessage = apiError(e);
      return false;
    } finally {
      if (generation == _generation) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  Future<Uint8List?> descargarComprobante(int idPago) async {
    final generation = _generation;
    _isDownloadingComprobante = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bytes = await _repository.descargarComprobante(idPago);
      return generation == _generation ? bytes : null;
    } catch (e) {
      if (generation == _generation) _errorMessage = apiError(e);
      return null;
    } finally {
      if (generation == _generation) {
        _isDownloadingComprobante = false;
        notifyListeners();
      }
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}

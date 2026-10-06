import 'package:flutter/foundation.dart';
import '../../data/models/contrato_model.dart';
import '../../data/repositories/contratos_repository.dart';

class ContratosProvider extends ChangeNotifier {
  ContratosProvider(this._repository);

  final ContratosRepository _repository;

  List<ContratoModel> _contratos = [];
  List<ContratoModel> get contratos => _contratos;

  ContratoModel? _detalle;
  ContratoModel? get detalle => _detalle;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  bool _isDownloadingComprobante = false;
  bool get isDownloadingComprobante => _isDownloadingComprobante;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  Future<void> fetchContratos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _contratos = await _repository.getContratos();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDetalle(int idContrato) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _detalle = await _repository.getContratoDetalle(idContrato);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
  }) async {
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
      );
      _contratos = [..._contratos, creado];
      _successMessage = 'Contrato #${creado.idContrato} creado correctamente.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<String?> registrarPago({
    required int idContrato,
    required double monto,
    required String metodoPago,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.registrarPago(
        idContrato: idContrato,
        monto: monto,
        metodoPago: metodoPago,
      );
      final recibo = result['numero_recibo'] as String? ?? '';
      _successMessage = 'Pago registrado. Recibo: $recibo';
      await fetchDetalle(idContrato);
      await fetchContratos();
      return recibo;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> eliminarContrato(int idContrato) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.eliminarContrato(idContrato);
      _contratos = _contratos.where((c) => c.idContrato != idContrato).toList();
      _successMessage = 'Contrato eliminado.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> descargarComprobante(int idPago) async {
    _isDownloadingComprobante = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _repository.descargarComprobante(idPago);
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isDownloadingComprobante = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
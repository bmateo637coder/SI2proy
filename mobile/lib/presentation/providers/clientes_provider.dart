import 'package:flutter/foundation.dart';

import '../../data/services/api_error.dart';
import '../../data/models/cliente_model.dart';
import '../../data/repositories/clientes_repository.dart';

class ClientesProvider extends ChangeNotifier {
  ClientesProvider(this._repository);

  final ClientesRepository _repository;
  int _generation = 0;
  int _listRequest = 0;
  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  void reset() {
    _generation++;
    _isCreating = false;
    _clientes = [];
    _isLoading = false;
    _errorMessage = null;

    notifyListeners();
  }

  List<ClienteModel> _clientes = [];
  List<ClienteModel> get clientes => _clientes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchClientes() async {
    final generation = _generation;
    final request = ++_listRequest;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getClientes();
      if (generation != _generation || request != _listRequest) return;
      _clientes = result;
    } catch (e) {
      if (generation != _generation || request != _listRequest) return;
      _errorMessage = apiError(e);
    } finally {
      if (generation == _generation && request == _listRequest) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createCliente(String ciUsuario) async {
    final generation = _generation;
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nuevo = await _repository.createCliente(ciUsuario.trim());
      if (generation != _generation) return false;
      _clientes = [..._clientes, nuevo];
      return true;
    } catch (e) {
      if (generation == _generation) _errorMessage = apiError(e);
      return false;
    } finally {
      if (generation == _generation) {
        _isCreating = false;
        notifyListeners();
      }
    }
  }
}

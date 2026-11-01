import 'package:flutter/foundation.dart';

import '../../data/services/api_error.dart';
import '../../data/models/cliente_model.dart';
import '../../data/repositories/clientes_repository.dart';

class ClientesProvider extends ChangeNotifier {
  ClientesProvider(this._repository);

  final ClientesRepository _repository;
  int _generation = 0;
  void reset() {
    _generation++;
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getClientes();
      if (generation != _generation) return;
      _clientes = result;
    } catch (e) {
      if (generation != _generation) return;
      _errorMessage = apiError(e);
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createCliente(String ciUsuario) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nuevo = await _repository.createCliente(ciUsuario.trim());
      _clientes = [..._clientes, nuevo];
      return true;
    } catch (e) {
      _errorMessage = apiError(e);
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }
}

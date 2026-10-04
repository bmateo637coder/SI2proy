import 'package:flutter/foundation.dart';
import '../../data/models/cliente_model.dart';
import '../../data/repositories/clientes_repository.dart';

class ClientesProvider extends ChangeNotifier {
  ClientesProvider(this._repository);

  final ClientesRepository _repository;

  List<ClienteModel> _clientes = [];
  List<ClienteModel> get clientes => _clientes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchClientes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _clientes = await _repository.getClientes();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
      _errorMessage = e.toString();
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }
}
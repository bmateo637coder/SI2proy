import 'package:flutter/foundation.dart';
import '../../data/models/propiedad_model.dart';
import '../../data/repositories/propiedades_repository.dart';

class PropiedadesProvider extends ChangeNotifier {
  PropiedadesProvider(this._repository);

  final PropiedadesRepository _repository;

  List<PropiedadModel> _propiedades = [];
  List<PropiedadModel> get propiedades => _propiedades;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPropiedades() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _propiedades = await _repository.getPropiedades();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

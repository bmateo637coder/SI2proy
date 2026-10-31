import 'package:flutter/foundation.dart';

import '../../data/services/api_error.dart';
import '../../data/models/propiedad_model.dart';
import '../../data/repositories/propiedades_repository.dart';

class PropiedadesProvider extends ChangeNotifier {
  PropiedadesProvider(this._repository);

  final PropiedadesRepository _repository;
  int _generation = 0;
  void reset() {
    _generation++;
    _propiedades = [];
    _isLoading = false;
    _errorMessage = null;

    notifyListeners();
  }

  List<PropiedadModel> _propiedades = [];
  List<PropiedadModel> get propiedades => _propiedades;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPropiedades() async {
    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getPropiedades();
      if (generation != _generation) return;
      _propiedades = result;
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
}

import 'package:dio/dio.dart';

String apiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String)
      return data['detail'] as String;
    if (error.response?.statusCode == 422)
      return 'Revisa los campos, columnas y filtros ingresados.';
    if (error.response?.statusCode == 401)
      return 'La sesión venció. Inicia sesión para conectar con el servidor.';
    if (error.response == null)
      return 'Sin conexión con el servidor. Puedes consultar los datos descargados en Offline.';
    return 'El servidor no pudo completar la solicitud. Vuelve a intentar.';
  }
  return error is StateError
      ? error.message.toString()
      : 'No se pudo completar la operación.';
}

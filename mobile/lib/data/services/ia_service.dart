import 'package:dio/dio.dart';

class IaService {
  IaService(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> get(String route) async =>
      Map<String, dynamic>.from((await dio.get(route)).data);
  Future<Map<String, dynamic>> post(
    String route,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    (await dio.post(
      route,
      data: data,
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    )).data,
  );
}

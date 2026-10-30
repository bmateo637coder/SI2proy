import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:typed_data'; // keep
import 'package:share_plus/share_plus.dart';

import '../../core/config/api_constants.dart';
import '../../data/network/auth_interceptor.dart';
import 'secure_storage_service.dart';

class ReportesService {
  ReportesService()
      : _storage = SecureStorageService(),
        _dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
          ),
        ) {
    _dio.interceptors.add(AuthInterceptor(_storage, () async {}));
  }

  final Dio _dio;
  final SecureStorageService _storage;

  Future<Map<String, dynamic>> generarReporte({
    required String entidad,
    required List<String> columnas,
    required List<Map<String, dynamic>> filtros,
    required String ordenColumna,
    required String ordenDireccion,
    int? idTenant,
  }) async {
    final res = await _dio.post(
      '/reportes/generar',
      data: {
        'entidad': entidad,
        'columnas': columnas,
        'filtros': filtros,
        'orden_columna': ordenColumna,
        'orden_direccion': ordenDireccion,
        if (idTenant != null) 'id_tenant': idTenant,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> listarGuardados() async {
    final res = await _dio.get('/reportes/listar');
    final data = res.data as List<dynamic>?;
    return data
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  Future<Map<String, dynamic>> cargarGuardado(int id) async {
    final res = await _dio.get('/reportes/cargar/$id');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<int?> guardarConfiguracion({
    required String nombre,
    required String entidad,
    required List<String> columnas,
    required List<Map<String, dynamic>> filtros,
    required String ordenColumna,
    required String ordenDireccion,
  }) async {
    final res = await _dio.post(
      '/reportes/guardar',
      data: {
        'nombre': nombre,
        'entidad': entidad,
        'columnas': columnas,
        'filtros': filtros,
        'orden_columna': ordenColumna,
        'orden_direccion': ordenDireccion,
      },
    );
    final data = res.data as Map<String, dynamic>?;
    return data?['id_reporte'] as int?;
  }

  Future<Map<String, dynamic>> comandoVoz(String texto) async {
    final res = await _dio.post(
      '/api/ia/reporte-voz',
      data: {'texto': texto},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<File> exportarPdf(List<Map<String, dynamic>> datos,
      List<String> columnas) async {
    final res = await _dio.post<List<int>>(
      '/reportes/exportar/pdf',
      data: {'datos': datos, 'columnas': columnas},
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(res.data ?? []);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportarCsv(List<Map<String, dynamic>> datos,
      List<String> columnas) async {
    final res = await _dio.post<List<int>>(
      '/reportes/exportar/csv',
      data: {'datos': datos, 'columnas': columnas},
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(res.data ?? []);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte.csv');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportarExcel(List<Map<String, dynamic>> datos,
      List<String> columnas) async {
    final res = await _dio.post<List<int>>(
      '/reportes/exportar/excel',
      data: {'datos': datos, 'columnas': columnas},
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(res.data ?? []);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportarHtml(List<Map<String, dynamic>> datos,
      List<String> columnas) async {
    final res = await _dio.post<List<int>>(
      '/reportes/exportar/html',
      data: {'datos': datos, 'columnas': columnas},
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = Uint8List.fromList(res.data ?? []);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/reporte.html');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> abrirYCompartir(File file) async {
    await OpenFilex.open(file.path);
    await Share.shareXFiles([XFile(file.path)]);
  }
}

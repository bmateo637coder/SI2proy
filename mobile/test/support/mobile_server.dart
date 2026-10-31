import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Backend controlado para probar errores de red sin crear ventas reales.
class MobileServer implements HttpClientAdapter {
  bool offline = false, loseReceipt = false;
  final requests = <RequestOptions>[];
  final accepted = <String>{};
  static const profile = {
    'ci': 'saas-test',
    'nombre': 'Superadministrador',
    'correo': 'saas@example.test',
    'id_rol': 1,
    'id_tenant': null,
  };
  static const companies = [
    {'id_tenant': 1, 'nombre': 'Raíces'},
    {'id_tenant': 2, 'nombre': 'Horizonte'},
  ];
  Map<String, dynamic> property(int tenant) => {
    'id_propiedad': tenant,
    'id_tenant': tenant,
    'id_sucursal': tenant,
    'inmobiliaria': tenant == 1 ? 'Raíces' : 'Horizonte',
    'titulo': 'Casa $tenant',
    'direccion': 'Centro',
    'precio': 1000,
    'estado': 'Disponible',
    'version': 1,
    'tipo_operacion': 'Venta',
    'imagenes': [],
  };
  ResponseBody json(Object data) => ResponseBody.fromString(
    jsonEncode(data),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline)
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Offline controlado',
      );
    final tenant =
        int.tryParse(
          '${options.headers['X-Tenant-ID'] ?? options.extra['tenantId']}',
        ) ??
        1;
    final all = options.headers['X-Tenant-Scope'] == 'all';
    final data = options.data is String
        ? jsonDecode(options.data)
        : options.data;
    switch (options.path) {
      case '/login':
        return json({
          'access_token': 'test-only-token',
          'token_type': 'bearer',
          'user': profile,
        });
      case '/users/me':
        return json(profile);
      case '/admin/empresas':
        return json(companies);
      case '/modulo_inmuebles/propiedades/catalogo':
        return json([
          if (all || tenant == 1) property(1),
          if (all || tenant == 2) property(2),
        ]);
      case '/reportes/guardados':
        return json([]);
      case '/reportes/generar':
        final cols = List<String>.from(data['columnas']);
        return json({
          'columnas': [if (all) 'inmobiliaria', ...cols],
          'data': [
            if (all || tenant == 1) property(1),
            if (all || tenant == 2) property(2),
          ],
          'truncado': false,
        });
      case '/api/saas/sucursales':
        return json([
          {'id_sucursal': tenant, 'nombre': 'Matriz'},
        ]);
      case '/api/ia/estado':
        return json({
          'configurada': true,
          'modelo': 'gemini-test',
          'plan_habilitado': true,
        });
      case '/api/analitica/reporte':
      case '/api/analitica/convencional':
        return json({
          'titulo': 'Cartera',
          'columnas': ['inmobiliaria', 'cantidad'],
          'filas': [
            ['Raíces', 1],
            if (all) ['Horizonte', 1],
          ],
          'interprete': 'reglas_locales',
        });
      case '/api/offline/catalogo':
        return json({
          'id_tenant': tenant,
          'ci_usuario': profile['ci'],
          'descargado_en': '2026-10-31T12:00:00Z',
          'sucursales': [
            {'id_sucursal': tenant, 'nombre': 'Matriz'},
          ],
          'clientes': [
            {'id_cliente': tenant, 'nombre': 'Cliente de prueba'},
          ],
          'propiedades': [property(tenant)],
        });
      case '/api/offline/sincronizar':
        final uuid = data['uuid'] as String;
        final duplicate = !accepted.add(uuid);
        if (loseReceipt) {
          loseReceipt = false;
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'Confirmación perdida',
          );
        }
        return json({
          'uuid': uuid,
          'estado': 'confirmada',
          'duplicada': duplicate,
        });
      default:
        throw StateError('Ruta no cubierta: ${options.path}');
    }
  }

  @override
  void close({bool force = false}) {}
}

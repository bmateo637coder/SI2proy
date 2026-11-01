import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Backend controlado para probar errores de red sin crear ventas reales.
class MobileServer implements HttpClientAdapter {
  bool offline = false, loseReceipt = false;
  final requests = <RequestOptions>[];
  final accepted = <String>{};
  bool replicaConflict = false;
  final replicaReceipts = <String, Map<String, dynamic>>{};
  final replicaContracts = <Map<String, dynamic>>[];
  final replicaReports = <Map<String, dynamic>>[];
  Map<String, dynamic> replicaBundle() => {
    'ci_usuario': profile['ci'],
    'id_tenant': null,
    'alcance': 'todas',
    'completo': true,
    'descargado_en': DateTime.now().toUtc().toIso8601String(),
    'datos': {
      'propiedades': [property(1), property(2)],
      'contratos': replicaContracts,
      'clientes': [
        for (final tid in [1, 2])
          {
            'id_cliente': tid,
            'id_tenant': tid,
            'nombre': 'Cliente de prueba',
            'ci': 'cliente-$tid',
            'correo': 'cliente$tid@example.test',
            'telefono': '123',
            'inmobiliaria': tid == 1 ? 'Raíces' : 'Horizonte',
          },
      ],
      'usuarios': [],
      'propietarios': [],
      'agentes': [],
      'reservas': [],
      'reportes': replicaReports,
      'planes': [],
      'roles': [],
      'sucursales': [
        for (final tid in [1, 2])
          {'id_sucursal': tid, 'id_tenant': tid, 'nombre': 'Matriz'},
      ],
    },
    'huellas': {'propiedad:1': 'a' * 64, 'propiedad:2': 'b' * 64},
  };
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
    if (options.path.startsWith('/api/offline/reservas/') &&
        options.path.endsWith('/cancelar'))
      return json({
        'uuid': options.path.split('/')[4],
        'estado': 'cancelada',
        'motivo': 'Reserva cancelada.',
      });
    switch (options.path) {
      case '/api/health':
        return json({'status': 'ok'});
      case '/api/analitica/dashboard':
        return json({
          'modelo': {'estado': 'datos_insuficientes'},
          'predicciones': [],
        });
      case '/api/replica/datos':
        return json(replicaBundle());
      case '/api/replica/cambios':
        final id = data['uuid'] as String;
        var result = replicaReceipts[id];
        if (result == null) {
          final values = Map<String, dynamic>.from(data['datos']);
          final tid = data['id_tenant'];
          final contract = {
            ...values,
            'id_contrato': 100 + replicaContracts.length,
            'id_tenant': tid,
            'inmobiliaria': tid == 1 ? 'Raíces' : 'Horizonte',
            'cliente': 'Cliente de prueba',
            'propiedad': 'Casa $tid',
            'estado': 'Activo',
            'saldo_pendiente': values['monto_total'],
            'pagos': [],
            'cuotas': [],
          };
          if (!replicaConflict && data['tipo'] == 'contrato.crear')
            replicaContracts.add(contract);
          final report = {
            ...values,
            'id_reporte': replicaReports.length + 1,
            'id_tenant': tid,
          };
          if (!replicaConflict && data['tipo'] == 'reporte.guardar')
            replicaReports.add(report);
          result = {
            'uuid': id,
            'estado': replicaConflict ? 'conflicto' : 'confirmada',
            'data': data['tipo'] == 'contrato.crear' ? contract : report,
            'huellas': {},
            if (replicaConflict) 'motivo': 'Otro usuario cambió el precio.',
            if (replicaConflict) 'servidor': {...property(tid), 'precio': 1500},
          };
          replicaReceipts[id] = result;
        }
        if (loseReceipt) {
          loseReceipt = false;
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'Respuesta perdida después de confirmar',
          );
        }
        return json(result);
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

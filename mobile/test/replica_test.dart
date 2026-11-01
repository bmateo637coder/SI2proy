import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:inmobiliaria_mobile/data/services/offline_identity.dart';
import 'package:inmobiliaria_mobile/data/services/local_reports.dart';
import 'package:inmobiliaria_mobile/data/services/replica_store.dart';
import 'package:inmobiliaria_mobile/data/services/replica_controller.dart';
import 'package:inmobiliaria_mobile/data/services/offline_service.dart';
import 'package:inmobiliaria_mobile/data/services/auth_service.dart';
import 'package:inmobiliaria_mobile/data/services/secure_storage_service.dart';
import 'package:inmobiliaria_mobile/data/repositories/auth_repository.dart';
import 'package:inmobiliaria_mobile/data/network/auth_interceptor.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';

import 'support/mobile_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late MobileServer server;
  late Dio dio;
  late AuthProvider auth;
  late ReplicaStore store;
  late ReplicaController controller;
  Future<AuthProvider> account() async {
    final storage = SecureStorageService();
    final result = AuthProvider(
      AuthRepository(AuthService(dio)),
      storage,
      offlineIdentity: OfflineIdentity(iterations: 1000),
    );
    return result;
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('replica-test-');
    server = MobileServer();
    dio = Dio()..httpClientAdapter = server;
    auth = await account();
    dio.interceptors.add(
      AuthInterceptor(SecureStorageService(), () => auth.sessionExpired()),
    );
    expect(await auth.signIn('saas@example.test', 'test-password'), isTrue);
    store = ReplicaStore(
      user: () => auth.user,
      databasePath: '${dir.path}/replica.db',
    );
    dio.interceptors.add(ReplicaInterceptor(store, auth));
    controller = ReplicaController(
      dio,
      auth,
      store,
      OfflineService(dio, databasePath: '${dir.path}/legacy.db'),
    );
    await controller.refresh(force: true);
    expect(await store.raw(), isNotNull);
  });
  tearDown(() async {
    controller.dispose();
    await (await controller.legacy.database).close();
    await (await store.database).close();
    dio.close(force: true);
    await dir.delete(recursive: true);
  });
  test('Entrada local tras cerrar sesión, contraseña validada y catálogo/reportes de todas o una sin red', () async {
    await auth.signOut();
    server.offline = true;
    expect(await auth.signIn('saas@example.test', 'wrong-password'), isFalse);
    expect(await auth.signIn('saas@example.test', 'test-password'), isTrue);
    store.online = false;
    expect(
      ((await dio.get('/modulo_inmuebles/propiedades/catalogo')).data as List),
      hasLength(2),
    );
    final config = {
      'entidad': 'propiedades',
      'columnas': ['titulo', 'precio'],
      'filtros': [
        {'columna': 'precio', 'operador': 'gte', 'valor': '900'},
      ],
      'orden': {'columna': 'precio', 'direccion': 'desc'},
    };
    expect(
      (await dio.post('/reportes/generar', data: config)).data['data'],
      hasLength(2),
    );
    await auth.selectTenant(2);
    expect(
      (await dio.post('/reportes/generar', data: config)).data['data'],
      hasLength(1),
    );
    expect(
      (await dio.post(
        '/api/analitica/convencional',
        data: {'tipo': 'cartera_estado'},
      )).data['origen'],
      'local',
    );
    expect(
      (await dio.post(
        '/api/analitica/reporte',
        data: {'texto': 'cartera por estado'},
      )).data['filas'],
      hasLength(1),
    );
  });
  test('Contrato y pago offline se ven en listas/reportes; SQLite conserva UUID y dependencias al reiniciar', () async {
    server.offline = true;
    store.online = false;
    await auth.selectTenant(2);
    final contract = (await dio.post(
      '/gestion_contractual/contratos',
      data: {
        'id_cliente': 2,
        'id_propiedad': 2,
        'tipo_contrato': 'Venta',
        'monto_total': 1000,
        'fecha_inicio': '2026-11-01',
        'num_cuotas': 2,
      },
    )).data;
    expect(contract['id_contrato'], lessThan(0));
    await dio.post(
      '/gestion_contractual/contratos/${contract['id_contrato']}/pagos',
      data: {'monto': 250, 'metodo_pago': 'Efectivo'},
    );
    final detail = (await dio.get(
      '/gestion_contractual/contratos/${contract['id_contrato']}',
    )).data;
    expect(detail['saldo_pendiente'], 750);
    expect(detail['pagos'], hasLength(1));
    expect(
      (await dio.get('/modulo_inmuebles/propiedades/catalogo')).data,
      isEmpty,
    );
    final report = (await dio.post(
      '/api/analitica/convencional',
      data: {'tipo': 'ingresos_semana'},
    )).data;
    expect((report['filas'] as List).single.last, 250);
    final ops = await store.operations();
    final uuid = ops.first['uuid'];
    expect(
      jsonDecode(ops.last['payload'] as String)['dependencias']['id'],
      uuid,
    );
    await (await store.database).close();
    store = ReplicaStore(
      user: () => auth.user,
      databasePath: '${dir.path}/replica.db',
    );
    expect((await store.operations()).first['uuid'], uuid);
    expect(
      (await store.view(tenant: 2))['contratos'].single['saldo_pendiente'],
      750,
    );
  });
  test('Reportes locales interpretan meses, sucursal, tipo y estado sin omitir filtros', () async {
    final spec = LocalReports.naturalSpec(
      'Ventas de febrero de 2024 en sucursal 2',
    );
    expect(spec['desde'], '2024-02-01');
    expect(spec['hasta'], '2024-02-29');
    expect(spec['id_sucursal'], 2);
    expect(spec['tipo_contrato'], 'Venta');
    final available = LocalReports.naturalSpec(
      'Cartera de propiedades disponibles',
    );
    expect(available['estado'], 'Disponible');
    expect(
      () => LocalReports.naturalSpec('Ventas de enero y febrero'),
      throwsStateError,
    );
    expect(
      () =>
          LocalReports.naturalSpec('Ventas desde 2026-02-31 hasta 2026-03-01'),
      throwsStateError,
    );
    expect(
      () => LocalReports.conventional({}, {
        'tipo': 'ventas_sucursal',
        'estado': 'Vendida',
      }, false),
      throwsStateError,
    );
  });
  test('Errores locales no contaminan SQLite y los pagos fraccionados cierran el saldo en centavos', () async {
    await auth.selectTenant(2);
    store.online = false;
    final body = {
      'id_cliente': 2,
      'id_propiedad': 2,
      'tipo_contrato': 'Venta',
      'monto_total': 0.3,
      'fecha_inicio': '2026-11-01',
      'num_cuotas': 1,
    };
    await expectLater(
      dio.post(
        '/gestion_contractual/contratos',
        data: {...body, 'num_cuotas': -2},
      ),
      throwsA(isA<DioException>()),
    );
    expect(await store.operations(), isEmpty);
    final c = (await dio.post(
      '/gestion_contractual/contratos',
      data: body,
    )).data;
    for (final amount in [0.1, 0.2])
      await dio.post(
        '/gestion_contractual/contratos/${c['id_contrato']}/pagos',
        data: {'monto': amount, 'metodo_pago': 'Efectivo'},
      );
    final detail = (await dio.get(
      '/gestion_contractual/contratos/${c['id_contrato']}',
    )).data;
    expect(detail['saldo_pendiente'], 0);
    expect(detail['estado'], 'Pagado');
    expect(detail['cuotas_pagadas'], 1);
  });
  test('Reservas locales afectan catálogo y reportes; cancelación queda guardada sin red', () async {
    final legacy = controller.legacy;
    final user = auth.user!.forTenant(2);
    final snapshot = await legacy.readSnapshot(user);
    await legacy.queue(
      user,
      Map<String, dynamic>.from(snapshot['propiedades'].single),
      2,
      'reserva',
    );
    store.legacyOperations = () => legacy.operations(user);
    final projected = await store.view(tenant: 2);
    expect((projected['propiedades'] as List).single['estado'], 'Reservada');
    store.online = false;
    final report = (await dio.post(
      '/api/analitica/convencional',
      data: {'tipo': 'reservas_sucursal'},
      options: Options(extra: {'tenantId': 2}),
    )).data;
    expect((report['filas'] as List).single.last, 1);
    await legacy.synchronize(user);
    final uuid = (await legacy.operations(user)).single['uuid'] as String;
    server.offline = true;
    await legacy.cancel(user, uuid);
    await legacy.synchronize(user);
    expect((await legacy.operations(user)).single['cancel_requested'], 1);
    await store.counters();
    expect(store.pending, 1);
    server.offline = false;
    await legacy.synchronize(user);
    expect((await legacy.operations(user)).single['status'], 'cancelada');
    await store.counters();
    expect(store.pending, 0);
  });
  test('Reintenta confirmación perdida sin duplicar y conserva propuestas con conflicto', () async {
    await auth.selectTenant(2);
    store.online = false;
    await dio.post(
      '/gestion_contractual/contratos',
      data: {
        'id_cliente': 2,
        'id_propiedad': 2,
        'tipo_contrato': 'Venta',
        'monto_total': 1000,
        'fecha_inicio': '2026-11-01',
        'num_cuotas': 1,
      },
    );
    server.loseReceipt = true;
    await controller.refresh(force: true);
    expect((await store.operations()).single['state'], 'pendiente');
    await controller.refresh(force: true);
    expect((await store.operations()).single['state'], 'confirmada');
    expect(server.replicaContracts, hasLength(1));
    await dio.post(
      '/reportes/guardados',
      data: {'nombre': 'Borrador local', 'configuracion': '{}'},
    );
    server.replicaConflict = true;
    await controller.refresh(force: true);
    expect(store.conflicts, 1);
    expect((await store.operations()).last['state'], 'conflicto');
    expect(
      jsonDecode(
        (await store.operations()).last['result'] as String,
      )['servidor']['precio'],
      1500,
    );
    await auth.signOut();
    expect(await store.raw(), isNull);
    expect(await store.operations(), isEmpty);
  });
}

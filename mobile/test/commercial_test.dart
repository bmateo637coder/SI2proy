import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:inmobiliaria_mobile/data/services/sprint4_service.dart';
import 'package:inmobiliaria_mobile/data/services/replica_store.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';
import 'package:inmobiliaria_mobile/presentation/screens/commercial_screen.dart';

import 'workspace_parity_test.dart' show WorkspaceAuth, WorkspaceService;
import 'sprint4_service_test.dart' show TestAuth;

class CommercialService extends WorkspaceService {
  CommercialService(super.d, super.a);
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? params,
    bool networkOnly = false,
  }) async {
    if (path.endsWith('/opciones'))
      return {'clientes': [], 'agentes': [], 'propiedades': []};
    if (path == '/api/workflow-ia')
      return [
        {
          'id': 1,
          'texto': 'Visitar la casa hoy',
          'categoria': 'Visita',
          'urgencia': 'Alta',
          'modo': 'local',
          'justificacion': 'Por palabras clave',
          'estado': 'Pendiente',
          'inmobiliaria': 'Raíces',
          'version': 1,
          'tareas': [
            {
              'titulo': 'Confirmar visita',
              'vence': '2026-11-22',
              'completada': false,
            },
          ],
          'historial': [],
        },
      ];
    return [
      {
        'id': 1,
        'titulo': 'Casa familiar',
        'contacto': 'Cliente',
        'importe': 1000,
        'probabilidad': 30,
        'etapa': 'Nuevo',
        'inmobiliaria': 'Raíces',
        'version': 1,
        'historial': [],
      },
    ];
  }

  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> mutate(
    String method,
    String path, [
    Map<String, dynamic> data = const {},
    int? version,
  ]) async {
    writes.add(data);
    return {'id': 1};
  }
}

class CommercialAdapter implements HttpClientAdapter {
  final commands = <Map>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    dynamic data = [];
    if (o.path == '/api/servicios/sync') {
      final cmd = Map.from(o.data as Map);
      commands.add(cmd);
      data = {
        ...cmd['datos'] as Map,
        'id': cmd['ruta'] == '/api/oportunidades' ? 101 : 201,
        'version': cmd['metodo'] == 'PUT' ? 2 : 1,
      };
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('offline opportunity dependency, stage, workflow tasks and versions survive until sync', () async {
    final dir = await Directory.systemTemp.createTemp('crm-offline-');
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    final adapter = CommercialAdapter();
    dio.httpClientAdapter = adapter;
    final auth = TestAuth(dio);
    final store = ReplicaStore(
      user: () => auth.user,
      databasePath: '${dir.path}/crm.db',
    );
    final service = Sprint4Service(dio, auth, store);
    try {
      await service.get('/api/oportunidades');
      await service.get('/api/workflow-ia');
      auth.localSession = true;
      final op = await service.mutate('POST', '/api/oportunidades', {
        'titulo': 'Casa familiar',
        'contacto': 'Cliente',
        'etapa': 'Nuevo',
        'importe': 100,
        'probabilidad': 20,
      });
      await service.mutate('PUT', '/api/oportunidades/${op['id']}', {
        'titulo': 'Casa familiar',
        'contacto': 'Cliente',
        'etapa': 'Visita',
        'importe': 100,
        'probabilidad': 50,
        'version': 1,
      }, 1);
      final projected = await service.get('/api/oportunidades') as List;
      expect(projected.single['etapa'], 'Visita');
      expect(projected.single['version'], 2);
      final wf = await service.mutate('POST', '/api/workflow-ia', {
        'texto': 'Quiero visitar una casa hoy',
        'id_oportunidad': op['id'],
      });
      await service.mutate('PUT', '/api/workflow-ia/${wf['id']}', {
        'tarea': 0,
        'completada': true,
        'version': 1,
      }, 1);
      final flows = await service.get('/api/workflow-ia') as List;
      expect(flows.single['categoria'], 'Visita');
      expect(flows.single['tareas'][0]['completada'], true);
      expect(adapter.commands, isEmpty);
      auth.localSession = false;
      auth.paused = false;
      await service.flush();
      expect(adapter.commands.length, 4);
      expect(adapter.commands[1]['ruta'], '/api/oportunidades/101');
      expect(adapter.commands[2]['datos']['id_oportunidad'], 101);
      expect(adapter.commands[3]['ruta'], '/api/workflow-ia/201');
      expect(
        (await service.changes()).where((r) => r['state'] == 'pendiente'),
        isEmpty,
      );
      auth.localSession = true;
      final discarded = await service.mutate('POST', '/api/oportunidades', {
        'titulo': 'Descartar prospecto',
        'contacto': 'Cliente',
        'etapa': 'Nuevo',
      });
      final child = await service.mutate('POST', '/api/workflow-ia', {
        'texto': 'Visitar casa hoy',
        'id_oportunidad': discarded['id'],
      });
      await service.mutate('PUT', '/api/workflow-ia/${child['id']}', {
        'tarea': 0,
        'completada': true,
        'version': 1,
      }, 1);
      await service.mutate('POST', '/api/alertas', {
        'texto': 'Casa centro',
        'nombre': 'Conservar alerta',
      });
      final queue = await service.changes();
      final parent = queue.firstWhere(
        (r) =>
            jsonDecode(r['command'] as String)['datos']['titulo'] ==
            'Descartar prospecto',
      );
      await service.discard(parent['uuid'] as String);
      final remaining = await service.changes();
      expect(remaining, hasLength(1));
      expect(
        jsonDecode(remaining.single['command'] as String)['ruta'],
        '/api/alertas',
      );
      expect(service.pending, 1);
    } finally {
      service.dispose();
      auth.dispose();
      await (await store.database).close();
      await dir.delete(recursive: true);
    }
  });
  Future<CommercialService> app(
    WidgetTester tester, {
    bool workflow = false,
  }) async {
    final dio = Dio(),
        auth = WorkspaceAuth(Dio()),
        service = CommercialService(Dio(), WorkspaceAuth(Dio()));
    addTearDown(service.dispose);
    addTearDown(service.auth.dispose);
    addTearDown(auth.dispose);
    addTearDown(dio.close);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<Sprint4Service>.value(value: service),
        ],
        child: MaterialApp(home: CommercialScreen(workflow: workflow)),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets(
    'phone Kanban shows real opportunity and stage controls without overflow',
    (tester) async {
      await app(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(find.text('Casa familiar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'workflow phone exposes reviewable tasks and records completion',
    (tester) async {
      final service = await app(tester, workflow: true);
      await tester.scrollUntilVisible(
        find.byType(Checkbox).first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(service.writes.last['completada'], true);
      expect(tester.takeException(), isNull);
    },
  );
}

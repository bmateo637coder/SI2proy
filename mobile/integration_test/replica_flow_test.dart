import 'dart:io';

import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:inmobiliaria_mobile/main.dart';
import 'package:inmobiliaria_mobile/data/network/auth_interceptor.dart';
import 'package:inmobiliaria_mobile/data/services/auth_service.dart';
import 'package:inmobiliaria_mobile/data/services/clientes_service.dart';
import 'package:inmobiliaria_mobile/data/services/contratos_service.dart';
import 'package:inmobiliaria_mobile/data/services/propiedades_service.dart';
import 'package:inmobiliaria_mobile/data/services/secure_storage_service.dart';
import 'package:inmobiliaria_mobile/data/services/offline_identity.dart';
import 'package:inmobiliaria_mobile/data/services/offline_service.dart';
import 'package:inmobiliaria_mobile/data/services/replica_store.dart';
import 'package:inmobiliaria_mobile/data/services/replica_controller.dart';
import 'package:inmobiliaria_mobile/data/services/reportes_service.dart';
import 'package:inmobiliaria_mobile/data/repositories/auth_repository.dart';
import 'package:inmobiliaria_mobile/data/repositories/clientes_repository.dart';
import 'package:inmobiliaria_mobile/data/repositories/contratos_repository.dart';
import 'package:inmobiliaria_mobile/data/repositories/propiedades_repository.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';
import 'package:inmobiliaria_mobile/presentation/providers/clientes_provider.dart';
import 'package:inmobiliaria_mobile/presentation/providers/contratos_provider.dart';
import 'package:inmobiliaria_mobile/presentation/providers/propiedades_provider.dart';

import '../test/support/mobile_server.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: copia automática, login sin red, catálogo habitual, reporte, cambios persistentes y conflictos',
    (tester) async {
      final dir = await Directory.systemTemp.createTemp('replica-native-');
      final server = MobileServer();
      final storage = SecureStorageService();
      await storage.clear();
      final dio = Dio()..httpClientAdapter = server;
      final auth = AuthProvider(
        AuthRepository(AuthService(dio)),
        storage,
        offlineIdentity: OfflineIdentity(iterations: 1000),
      );
      dio.interceptors.add(AuthInterceptor(storage, auth.sessionExpired));
      final store = ReplicaStore(
        user: () => auth.user,
        databasePath: '${dir.path}/replica.db',
      );
      final replica = ReplicaInterceptor(store, auth);
      dio.interceptors.add(replica);
      final legacy = OfflineService(dio, databasePath: '${dir.path}/legacy.db');
      final properties = PropiedadesProvider(
        PropiedadesRepository(PropiedadesService(dio)),
      );
      final clients = ClientesProvider(
        ClientesRepository(ClientesService(dio)),
      );
      final contracts = ContratosProvider(
        ContratosRepository(ContratosService(dio)),
      );
      auth.onScopeChanged = () {
        properties.reset();
        clients.reset();
        contracts.reset();
      };
      expect(await auth.signIn('saas@example.test', 'test-password'), isTrue);
      await tester.pumpWidget(
        InmobiliariaApp(
          dio: dio,
          auth: auth,
          propiedadesProvider: properties,
          clientesProvider: clients,
          contratosProvider: contracts,
          offlineService: legacy,
          replica: store,
          replicaInterceptor: replica,
        ),
      );
      await tester.pumpAndSettle();
      // El arranque prepara SQLite sin pulsar Descargar ni visitar Offline.
      await tester.runAsync(() async {
        for (var i = 0; i < 200 && await store.raw() == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pumpAndSettle();
      expect(await store.raw(), isNotNull);
      expect(find.text('2 propiedades'), findsOneWidget);
      server.offline = true;
      store.online = false;
      await auth.signOut();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'saas@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(auth.localSession, isTrue);
      expect(find.text('2 propiedades'), findsOneWidget);
      await auth.selectTenant(2);
      await tester.pumpAndSettle();
      expect(find.text('1 propiedades'), findsOneWidget);
      final config = {
        'entidad': 'propiedades',
        'columnas': ['titulo', 'precio'],
        'filtros': [],
      };
      final report = await ReportesService(dio).generar(config);
      expect(report['data'], hasLength(1));
      expect(report['origen'], 'local');
      final pdf = await ReportesService.bytes(
        'pdf',
        List<String>.from(report['columnas']),
        (report['data'] as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
      );
      expect(pdf.take(4), [37, 80, 68, 70]);
      await dio.post(
        '/gestion_contractual/contratos',
        data: {
          'id_cliente': 2,
          'id_propiedad': 2,
          'tipo_contrato': 'Venta',
          'monto_total': 1000,
          'fecha_inicio': '2026-11-01',
          'num_cuotas': 2,
        },
      );
      await tester.pumpAndSettle();
      expect((await store.operations()).single['state'], 'pendiente');
      final uuid = (await store.operations()).single['uuid'];
      final reopened = ReplicaStore(
        user: () => auth.user,
        databasePath: '${dir.path}/replica.db',
      );
      expect((await reopened.operations()).single['uuid'], uuid);
      expect((await reopened.view(tenant: 2))['contratos'], hasLength(1));
      server.offline = false;
      server.replicaConflict = true;
      final context = tester.element(
        find.byKey(const ValueKey('catalog-count')),
      );
      // El controlador de producción sube automáticamente al volver a primer plano.
      final controller = context.read<ReplicaController>();
      await tester.runAsync(() async {
        // Espera a que el intento offline del controlador de la app libere la cola.
        for (var i = 0; i < 100 && controller.busy; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await controller.refresh(force: true);
      });
      await tester.pumpAndSettle();
      expect(store.conflicts, 1);
      expect(server.replicaContracts, isEmpty);
      expect(context.mounted, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await (await store.database).close();
      await (await legacy.database).close();
      await storage.clear();
      await dir.delete(recursive: true);
    },
  );
}

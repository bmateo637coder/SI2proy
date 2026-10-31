import 'dart:io';

import 'package:dio/dio.dart';
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
import 'package:inmobiliaria_mobile/data/services/offline_service.dart';
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
    'Android: SaaS global, reportes, selección y SQLite tras reinicio sin conexión',
    (tester) async {
      final server = MobileServer();
      final storage = SecureStorageService();
      await storage.clear();
      final dir = await Directory.systemTemp.createTemp('raices-integration-');
      final database = '${dir.path}/offline.db';
      late AuthProvider auth;
      late OfflineService offline;
      Future<InmobiliariaApp> app({bool restore = false}) async {
        final dio = Dio()..httpClientAdapter = server;
        auth = AuthProvider(AuthRepository(AuthService(dio)), storage);
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
        dio.interceptors.add(AuthInterceptor(storage, auth.signOut));
        offline = OfflineService(dio, databasePath: database);
        if (restore) await auth.restoreSession();
        return InmobiliariaApp(
          dio: dio,
          auth: auth,
          propiedadesProvider: properties,
          clientesProvider: clients,
          contratosProvider: contracts,
          offlineService: offline,
        );
      }

      await tester.pumpWidget(await app());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'saas@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'test-password');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('2 propiedades'), findsOneWidget);
      await tester.tap(find.text('Reportes').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Generar reporte'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Generar reporte'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('2 registros'), 150, scrollable: find.byType(Scrollable).first);
      expect(find.text('2 registros'), findsOneWidget);
      await tester.tap(find.text('Catálogo').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('IA y analítica'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Generar reporte convencional'), 150, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Generar reporte convencional'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('2 registros'), 150, scrollable: find.byType(Scrollable).first);
      expect(find.text('2 registros'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await auth.selectTenant(2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catálogo').last);
      await tester.pumpAndSettle();
      expect(find.text('1 propiedades'), findsOneWidget);
      await tester.tap(find.text('Offline').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargar catálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Casa 2'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente de prueba').last);
      await tester.pumpAndSettle();
      server.offline = true;
      await tester.scrollUntilVisible(find.text('Reservar'), 150, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Reservar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar en dispositivo'));
      await tester.pumpAndSettle();
      final user = auth.operationUser!;
      final uuid = (await offline.operations(user)).single['uuid'];
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await (await offline.database).close();
      await tester.pumpWidget(await app(restore: true));
      await tester.pumpAndSettle();
      expect(auth.localSession, isTrue);
      expect(auth.selectedTenant, 2);
      await tester.tap(find.text('Offline').last);
      await tester.pumpAndSettle();
      expect(
        (await offline.operations(auth.operationUser!)).single['uuid'],
        uuid,
      );
      expect(find.text('Casa 2'), findsOneWidget);
      server.offline = false;
      server.loseReceipt = true;
      await tester.tap(find.text('Sincronizar'));
      await tester.pumpAndSettle();
      expect(
        (await offline.operations(auth.operationUser!)).single['status'],
        'pendiente',
      );
      await tester.tap(find.text('Sincronizar'));
      await tester.pumpAndSettle();
      expect(
        (await offline.operations(auth.operationUser!)).single['status'],
        'confirmada',
      );
      expect(server.accepted, hasLength(1));
      expect(server.accepted.single, uuid);
      await auth.selectTenant(1);
      await tester.pumpAndSettle();
      expect(find.text('Casa 2'), findsNothing);
      expect(await offline.operations(auth.operationUser!), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await (await offline.database).close();
      await storage.clear();
      await dir.delete(recursive: true);
    },
  );
}

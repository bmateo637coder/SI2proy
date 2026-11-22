import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inmobiliaria_mobile/data/models/user_model.dart';
import 'package:inmobiliaria_mobile/data/repositories/auth_repository.dart';
import 'package:inmobiliaria_mobile/data/services/auth_service.dart';
import 'package:inmobiliaria_mobile/data/services/secure_storage_service.dart';
import 'package:inmobiliaria_mobile/data/services/replica_store.dart';
import 'package:inmobiliaria_mobile/data/services/sprint4_service.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';
import 'package:inmobiliaria_mobile/presentation/screens/admin/management_screen.dart';
import 'package:inmobiliaria_mobile/presentation/screens/workspace_screen.dart';
import 'package:inmobiliaria_mobile/presentation/widgets/workspace_modules.dart';

class WorkspaceAuth extends AuthProvider {
  WorkspaceAuth(Dio dio)
    : super(AuthRepository(AuthService(dio)), SecureStorageService()) {
    selectedTenant = 1;
  }
  @override
  UserModel get user => UserModel.fromJson({
    'ci': 'super',
    'id_rol': 1,
    'id_tenant': 0,
    'nombre': 'SaaS',
    'correo': 'test@example.com',
  });
  @override
  UserModel get operationUser => user.forTenant(selectedTenant ?? 0);
  @override
  bool get isSuperAdmin => true;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
  @override
  String get scopeKey => 'super|$selectedTenant';
}

class WorkspaceAdapter implements HttpClientAdapter {
  bool reject = true;
  final writes = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    writes.add(options);
    return ResponseBody.fromString(
      jsonEncode(
        reject ? {'detail': 'Este correo ya está registrado'} : {'ok': true},
      ),
      reject ? 409 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class WorkspaceService extends Sprint4Service {
  WorkspaceService(Dio d, AuthProvider a)
    : super(d, a, ReplicaStore(user: () => a.user)) {
    timer?.cancel();
    timer = null;
  }
  @override
  Future<void> refresh() async {}
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? params,
    bool networkOnly = false,
  }) async {
    if (path == '/roles')
      return [
        {
          'id_rol': 3,
          'nombre': 'Agente',
          'id_tenant': null,
          'permisos': <int>[],
        },
      ];
    return <dynamic>[];
  }
}

void main() {
  testWidgets('Search results remain visible above the phone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final auth = WorkspaceAuth(Dio());
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: WorkspaceScreen()),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('workspace-search')),
      'bitacora',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bitácora'), findsOneWidget);
    expect(tester.getBottomRight(find.text('Bitácora')).dy, lessThan(440));
    expect(find.text('Tu inmobiliaria, a la mano'), findsNothing);
  });
  test('La búsqueda de funciones encuentra textos sin escribir tildes', () {
    expect(workspaceSearch('Bitácora y Búsqueda'), contains('bitacora'));
    expect(workspaceSearch('Bitácora y Búsqueda'), contains('busqueda'));
  });
  test('SaaS reaches all web administrative modules; customers do not get staff menus', () {
    final root = UserModel.fromJson({
      'ci': 'super',
      'id_rol': 1,
      'id_tenant': 0,
    });
    final paths = workspaceModules(root).map((m) => m.path).toSet();
    for (final name in [
      'propiedades',
      'propietarios',
      'agentes',
      'clientes',
      'usuarios',
      'roles',
      'empresas',
      'global',
      'planes',
      'sucursales',
      'bitacora',
      'respaldos',
    ]) {
      expect(paths, contains('/gestion/$name'));
    }
    expect(paths, containsAll(['/ia', '/reportes', '/contratos']));
    final customer = UserModel.fromJson({
      'ci': 'cliente',
      'id_rol': 4,
      'id_tenant': 1,
    });
    expect(
      workspaceModules(customer).any((m) => m.group == 'Plataforma SaaS'),
      isFalse,
    );
    expect(ManagementScreenTitles.allowed('respaldos', customer), isFalse);
  });

  testWidgets(
    'mobile user form sends selected role and concrete tenant, without hiding server errors',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      final adapter = WorkspaceAdapter();
      dio.httpClientAdapter = adapter;
      final auth = WorkspaceAuth(dio);
      final service = WorkspaceService(dio, auth);
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Dio>.value(value: dio),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<Sprint4Service>.value(value: service),
          ],
          child: const MaterialApp(home: ManagementScreen(module: 'usuarios')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      for (final entry in {
        'ci': 'DEMO9',
        'nombre': 'Cuenta de prueba',
        'correo': 'cuenta@example.com',
        'password': 'Password123@',
      }.entries) {
        await tester.ensureVisible(find.byKey(ValueKey('field-${entry.key}')));
        await tester.enterText(
          find.byKey(ValueKey('field-${entry.key}')),
          entry.value,
        );
      }
      await tester.ensureVisible(find.text('Rol'));
      await tester.tap(find.text('Rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agente').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Este correo ya está registrado'), findsOneWidget);
      expect(find.text('Registrar usuario'), findsOneWidget);
      adapter.reject = false;
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(adapter.writes.where((r) => r.method == 'POST').length, 2);
      final payload = adapter.writes.last.data as Map;
      expect(payload['id_tenant'], 1);
      expect(payload['id_rol'], 3);
      expect(payload['ci'], 'DEMO9');
      expect(find.text('Registrar usuario'), findsNothing);
    },
  );
}

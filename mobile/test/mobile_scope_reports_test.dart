import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:inmobiliaria_mobile/data/network/auth_interceptor.dart';
import 'package:inmobiliaria_mobile/data/services/auth_service.dart';
import 'package:inmobiliaria_mobile/data/services/secure_storage_service.dart';
import 'package:inmobiliaria_mobile/data/services/reportes_service.dart';
import 'package:inmobiliaria_mobile/data/repositories/auth_repository.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';

import 'support/mobile_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MobileServer server;
  late Dio dio;
  late AuthProvider auth;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    server = MobileServer();
    dio = Dio()..httpClientAdapter = server;
    auth = AuthProvider(AuthRepository(AuthService(dio)), storage);
    dio.interceptors.add(AuthInterceptor(storage, auth.signOut));
  });
  test('Super SaaS cambia todas/una, identidad no recibe contexto y conserva alcance sin red', () async {
    var publishedBeforeReady = false;
    auth.addListener(() {
      if (auth.isLoading && auth.isAuthenticated) publishedBeforeReady = true;
    });
    expect(await auth.signIn('saas@example.test', 'test-password'), isTrue);
    expect(
      publishedBeforeReady,
      isFalse,
      reason: 'El router solo debe ver la identidad después de preparar credenciales locales y reiniciar proveedores.',
    );
    expect(auth.allTenants, isTrue);
    expect(auth.canWrite, isFalse);
    final reports = ReportesService(dio);
    final config = {
      'entidad': 'propiedades',
      'columnas': ['titulo', 'precio'],
      'filtros': [],
      'orden': {'columna': 'precio', 'direccion': 'desc'},
    };
    expect((await reports.generar(config))['data'], hasLength(2));
    expect(server.requests.last.headers['X-Tenant-Scope'], 'all');
    expect(server.requests.last.headers.containsKey('X-Tenant-ID'), isFalse);
    await auth.selectTenant(2);
    expect(auth.operationUser!.canOperateOffline, isTrue);
    expect(auth.operationUser!.idTenant, 2);
    expect(auth.user!.idTenant, 0); // La identidad sigue siendo global.
    expect((await reports.generar(config))['data'], hasLength(1));
    expect(server.requests.last.headers['X-Tenant-ID'], '2');
    await dio.get('/users/me');
    expect(server.requests.last.headers.containsKey('X-Tenant-ID'), isFalse);
    expect(server.requests.last.headers.containsKey('X-Tenant-Scope'), isFalse);
    server.offline = true;
    final restored = AuthProvider(
      AuthRepository(AuthService(dio)),
      SecureStorageService(),
    );
    await restored.restoreSession();
    expect(restored.localSession, isTrue);
    expect(restored.selectedTenant, 2);
    expect(restored.operationUser!.canOperateOffline, isTrue);
    expect(restored.companies, hasLength(2));
  });
  test('Exportaciones válidas escapan HTML, fórmulas CSV y generan XLSX/PDF locales', () async {
    final rows = [
      {'titulo': '=1+1', 'precio': '<script>&"'},
    ];
    final cols = ['titulo', 'precio'];
    final csv = utf8.decode(await ReportesService.bytes('csv', cols, rows));
    expect(csv, contains("'=1+1"));
    final html = utf8.decode(await ReportesService.bytes('html', cols, rows));
    expect(html, contains('&lt;script&gt;&amp;'));
    expect(html, isNot(contains('<script>')));
    final archive = ZipDecoder().decodeBytes(
      await ReportesService.bytes('xlsx', cols, rows),
    );
    expect(archive.findFile('xl/workbook.xml'), isNotNull);
    final sheet = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content,
    );
    expect(sheet, contains('inlineStr'));
    expect(sheet, contains('=1+1'));
    expect(sheet, isNot(contains('<f>')));
    final pdf = await ReportesService.bytes('pdf', cols, rows);
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
  });
}

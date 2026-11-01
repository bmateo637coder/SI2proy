import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:inmobiliaria_mobile/data/network/auth_interceptor.dart';
import 'package:inmobiliaria_mobile/data/services/auth_service.dart';
import 'package:inmobiliaria_mobile/data/services/secure_storage_service.dart';
import 'package:inmobiliaria_mobile/data/services/offline_service.dart';
import 'package:inmobiliaria_mobile/data/repositories/auth_repository.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';
import 'support/mobile_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('Super SaaS aísla descargas y colas; sincronización fija la inmobiliaria original', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    final server = MobileServer();
    final dio = Dio()..httpClientAdapter = server;
    final auth = AuthProvider(AuthRepository(AuthService(dio)), storage);
    dio.interceptors.add(AuthInterceptor(storage, auth.signOut));
    await auth.signIn('saas@example.test', 'test-password');
    final dir = await Directory.systemTemp.createTemp('raices-saas-');
    final offline = OfflineService(dio, databasePath: '${dir.path}/test.db');
    await expectLater(offline.download(auth.operationUser!), throwsStateError);
    await auth.selectTenant(1);
    final first = auth.operationUser!;
    await offline.download(first);
    await offline.queue(first, server.property(1), 1, 'reserva');
    await expectLater(offline.queue(first, server.property(1), 1, 'reserva'), throwsStateError);
    await auth.selectTenant(2);
    final second = auth.operationUser!;
    expect((await offline.readSnapshot(second))['propiedades'], isEmpty);
    expect(await offline.operations(second), isEmpty);
    await offline.download(second);
    await offline.queue(second, server.property(2), 2, 'venta_contado');
    await auth.selectTenant(0);
    // Una petición iniciada antes del cambio nunca toma el nuevo alcance global.
    await offline.synchronize(first);
    expect(server.requests.last.headers['X-Tenant-ID'], '1');
    expect(server.requests.last.headers.containsKey('X-Tenant-Scope'), isFalse);
    expect((await offline.operations(first)).single['status'], 'confirmada');
    expect((await offline.operations(second)).single['status'], 'local');
    await offline.synchronize(second);
    expect(server.requests.last.headers['X-Tenant-ID'], '2');
    expect(server.accepted, hasLength(2));
    await (await offline.database).close();
    await dir.delete(recursive: true);
  });
}

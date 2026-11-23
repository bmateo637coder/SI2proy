import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:inmobiliaria_mobile/data/models/user_model.dart';
import 'package:inmobiliaria_mobile/data/repositories/auth_repository.dart';
import 'package:inmobiliaria_mobile/data/services/auth_service.dart';
import 'package:inmobiliaria_mobile/data/services/secure_storage_service.dart';
import 'package:inmobiliaria_mobile/data/services/replica_store.dart';
import 'package:inmobiliaria_mobile/data/services/sprint4_service.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';

class TestAuth extends AuthProvider {
  TestAuth(Dio dio)
    : super(AuthRepository(AuthService(dio)), SecureStorageService());
  String ci = 'cuenta1';
  bool paused = true;
  @override
  UserModel get user => UserModel.fromJson({
    'ci': ci,
    'id_rol': 2,
    'id_tenant': 1,
    'correo': '$ci@example.com',
    'nombre': ci,
    'permisos': <String>[],
  });
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => paused;
}

class Adapter implements HttpClientAdapter {
  bool network = true;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    if (!network)
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    dynamic data = [];
    if (options.path.endsWith('/catalogo'))
      data = [
        {
          'id_propiedad': 1,
          'titulo': 'Casa Centro',
          'direccion': 'Centro',
          'precio': 1000,
          'estado': 'Disponible',
          'tipo_operacion': 'Venta',
          'caracteristicas': [
            {'nombre': 'Cuartos', 'valor': '3'},
          ],
        },
      ];
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('favorito offline persiste, se proyecta en pantalla y no pasa a otra cuenta', () async {
    final dir = await Directory.systemTemp.createTemp('s4-offline-');
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid'));
    final adapter = Adapter();
    dio.httpClientAdapter = adapter;
    final auth = TestAuth(dio);
    final store = ReplicaStore(
      user: () => auth.user,
      databasePath: '${dir.path}/replica.db',
    );
    final service = Sprint4Service(dio, auth, store);
    try {
      await service.get('/modulo_inmuebles/propiedades/catalogo');
      await service.get('/api/favoritos');
      auth.localSession = true;
      adapter.network = false;
      final pending = await service.mutate('POST', '/api/favoritos/1');
      expect(pending['pendiente'], true);
      expect(
        (await service.get(
          '/api/favoritos',
        ) as List).single['propiedad']['titulo'],
        'Casa Centro',
      );
      final search = await service.search(
        'casa en venta con tres habitaciones hasta 2 mil',
      );
      expect(search['resultados'], hasLength(1));
      service.dispose();
      final reopened = Sprint4Service(dio, auth, store);
      expect(await reopened.changes(), hasLength(1));
      auth.ci = 'otra-cuenta';
      expect(await reopened.changes(), isEmpty);
      await expectLater(reopened.get('/api/favoritos'), throwsStateError);
      reopened.dispose();
    } finally {
      await (await store.database).close();
      dio.close();
      auth.dispose();
      await dir.delete(recursive: true);
    }
  });
}

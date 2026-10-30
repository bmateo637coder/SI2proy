import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:inmobiliaria_mobile/data/models/user_model.dart';
import 'package:inmobiliaria_mobile/data/services/offline_service.dart';

class FakeServer implements HttpClientAdapter {
  bool loseFirstReceipt = true;
  final accepted = <String>{};
  int requests = 0;
  final prop = <String, dynamic>{
    'id_propiedad': 1,
    'id_sucursal': 1,
    'titulo': 'Casa',
    'direccion': 'Centro',
    'precio': '1000.00',
    'estado': 'Disponible',
    'version': 1,
    'tipo_operacion': 'Venta',
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/catalogo')) {
      return ResponseBody.fromString(
        jsonEncode({
          'id_tenant': 1,
          'ci_usuario': 'admin1',
          'descargado_en': '2026-10-30T10:00:00Z',
          'sucursales': [
            {'id_sucursal': 1, 'nombre': 'Matriz'},
          ],
          'clientes': [
            {'id_cliente': 1, 'nombre': 'Cliente'},
          ],
          'propiedades': [prop],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    requests++;
    final data = options.data is String
        ? jsonDecode(options.data as String) as Map<String, dynamic>
        : options.data as Map<String, dynamic>;
    final uuid = data['uuid'] as String;
    final duplicate = !accepted.add(uuid);
    if (loseFirstReceipt) {
      loseFirstReceipt = false;
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Se perdió la respuesta tras confirmar en servidor.',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'uuid': uuid,
        'estado': 'confirmada',
        'duplicada': duplicate,
      }),
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
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final user = UserModel.fromJson({
    'ci': 'admin1',
    'id_tenant': 1,
    'id_rol': 2,
  });
  test(
    'SQLite sobrevive reinicio y reintenta sin cambiar UUID ni duplicar venta',
    () async {
      final dir = await Directory.systemTemp.createTemp('raices-sqlite-');
      final file = '${dir.path}/offline.db';
      final server = FakeServer();
      final dio = Dio()..httpClientAdapter = server;
      final original = OfflineService(dio, databasePath: file);
      await original.download(user);
      await original.queue(user, server.prop, 1, 'venta_contado');
      final uuid = (await original.operations(user)).single['uuid'];
      await (await original.database).close();
      final reopened = OfflineService(dio, databasePath: file);
      expect((await reopened.readSnapshot(user))['propiedades'], hasLength(1));
      expect((await reopened.operations(user)).single['status'], 'local');
      await reopened.synchronize(user);
      expect((await reopened.operations(user)).single['status'], 'pendiente');
      await reopened.synchronize(user);
      final saved = (await reopened.operations(user)).single;
      expect(saved['status'], 'confirmada');
      expect(saved['uuid'], uuid);
      expect(server.requests, 2);
      expect(server.accepted, hasLength(1));
      expect(
        await reopened.operations(
          UserModel.fromJson({'ci': 'admin2', 'id_tenant': 2}),
        ),
        isEmpty,
      );
      await (await reopened.database).close();
      await dir.delete(recursive: true);
    },
  );
}

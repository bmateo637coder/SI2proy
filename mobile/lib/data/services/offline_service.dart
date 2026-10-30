import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../../core/config/api_constants.dart';

class OfflineService {
  OfflineService(this.dio, {this.databasePath});
  final Dio dio;
  final String? databasePath;
  Database? _database;
  Future<Database>? _opening;
  bool syncing = false;

  String scope(UserModel user) =>
      '${ApiConstants.baseUrl}|${user.idTenant}|${user.ci}';

  Future<Database> get database async {
    if (_database != null) return _database!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final db = await openDatabase(
      databasePath ??
          path.join(await getDatabasesPath(), 'raices_offline_v1.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE snapshot (scope TEXT PRIMARY KEY, downloaded_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE branch (scope TEXT NOT NULL, id INTEGER NOT NULL, name TEXT NOT NULL, PRIMARY KEY(scope,id))',
        );
        await db.execute(
          'CREATE TABLE client (scope TEXT NOT NULL, id INTEGER NOT NULL, name TEXT NOT NULL, PRIMARY KEY(scope,id))',
        );
        await db.execute(
          'CREATE TABLE property (scope TEXT NOT NULL, id INTEGER NOT NULL, branch_id INTEGER NOT NULL, data TEXT NOT NULL, PRIMARY KEY(scope,id), FOREIGN KEY(scope,branch_id) REFERENCES branch(scope,id))',
        );
        await db.execute(
          'CREATE TABLE operation (scope TEXT NOT NULL, uuid TEXT NOT NULL, property_id INTEGER NOT NULL, client_id INTEGER NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL, message TEXT, result TEXT, PRIMARY KEY(scope,uuid), FOREIGN KEY(scope,property_id) REFERENCES property(scope,id), FOREIGN KEY(scope,client_id) REFERENCES client(scope,id))',
        );
        await db.execute(
          'CREATE INDEX operation_pending ON operation(scope,status)',
        );
      },
    );
    _database = db;
    return db;
  }

  Future<Map<String, dynamic>> readSnapshot(UserModel user) async {
    final db = await database;
    final key = scope(user);
    final meta = await db.query(
      'snapshot',
      where: 'scope = ?',
      whereArgs: [key],
    );
    final properties = await db.query(
      'property',
      where: 'scope = ?',
      whereArgs: [key],
    );
    final clients = await db.query(
      'client',
      where: 'scope = ?',
      whereArgs: [key],
    );
    final branches = await db.query(
      'branch',
      where: 'scope = ?',
      whereArgs: [key],
    );
    return {
      'descargado_en': meta.isEmpty ? null : meta.first['downloaded_at'],
      'propiedades': properties
          .map((p) => jsonDecode(p['data'] as String) as Map<String, dynamic>)
          .toList(),
      'clientes': clients,
      'sucursales': branches,
    };
  }

  Future<void> download(UserModel user) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api/offline/catalogo',
    );
    final data = response.data!;
    if (data['id_tenant'] != user.idTenant || data['ci_usuario'] != user.ci) {
      throw StateError('La respuesta pertenece a otra sesión.');
    }
    final db = await database;
    final key = scope(user);
    await db.transaction((tx) async {
      // Actualizar sin REPLACE conserva las FK de operaciones históricas.
      // Los ausentes quedan marcados como no disponibles para nuevas operaciones.
      final old = await tx.query(
        'property',
        where: 'scope = ?',
        whereArgs: [key],
      );
      for (final row in old) {
        final prop = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        prop['estado'] = 'No disponible en descarga actual';
        await tx.update(
          'property',
          {'data': jsonEncode(prop)},
          where: 'scope = ? AND id = ?',
          whereArgs: [key, row['id']],
        );
      }
      for (final b in data['sucursales'] as List) {
        final values = {
          'scope': key,
          'id': b['id_sucursal'],
          'name': b['nombre'],
        };
        final changed = await tx.update(
          'branch',
          values,
          where: 'scope = ? AND id = ?',
          whereArgs: [key, b['id_sucursal']],
        );
        if (changed == 0) {
          await tx.insert('branch', values);
        }
      }
      for (final c in data['clientes'] as List) {
        final values = {
          'scope': key,
          'id': c['id_cliente'],
          'name': c['nombre'],
        };
        final changed = await tx.update(
          'client',
          values,
          where: 'scope = ? AND id = ?',
          whereArgs: [key, c['id_cliente']],
        );
        if (changed == 0) {
          await tx.insert('client', values);
        }
      }
      for (final p in data['propiedades'] as List) {
        final values = {
          'scope': key,
          'id': p['id_propiedad'],
          'branch_id': p['id_sucursal'],
          'data': jsonEncode(p),
        };
        final changed = await tx.update(
          'property',
          values,
          where: 'scope = ? AND id = ?',
          whereArgs: [key, p['id_propiedad']],
        );
        if (changed == 0) {
          await tx.insert('property', values);
        }
      }
      final values = {'scope': key, 'downloaded_at': data['descargado_en']};
      final changed = await tx.update(
        'snapshot',
        values,
        where: 'scope = ?',
        whereArgs: [key],
      );
      if (changed == 0) {
        await tx.insert('snapshot', values);
      }
    });
  }

  Future<List<Map<String, dynamic>>> operations(UserModel user) async {
    final db = await database;
    return db.query(
      'operation',
      where: 'scope = ?',
      whereArgs: [scope(user)],
      orderBy: 'rowid DESC',
    );
  }

  Future<void> queue(
    UserModel user,
    Map<String, dynamic> prop,
    int clientId,
    String type,
  ) async {
    if (prop['estado'] != 'Disponible' ||
        (type == 'venta_contado' && prop['tipo_operacion'] != 'Venta')) {
      throw StateError('Propiedad no disponible para esta operación.');
    }
    final key = scope(user);
    final db = await database;
    await db.transaction((tx) async {
      final exists = await tx.query(
        'operation',
        where: "scope = ? AND property_id = ? AND status IN ('local','pendiente','enviando','confirmada')",
        whereArgs: [key, prop['id_propiedad']],
      );
      if (exists.any(
        (row) =>
            row['status'] != 'confirmada' ||
            (jsonDecode(row['payload'] as String)
                    as Map<String, dynamic>)['version'] ==
                prop['version'],
      )) {
        throw StateError('Ya existe una operación local para esta propiedad.');
      }
      final uuid = const Uuid().v4();
      final payload = {
        'uuid': uuid,
        'id_tenant': user.idTenant,
        'ci_usuario': user.ci,
        'id_sucursal': prop['id_sucursal'],
        'id_propiedad': prop['id_propiedad'],
        'id_cliente': clientId,
        'tipo': type,
        'registrado_en': DateTime.now().toUtc().toIso8601String(),
        'version': prop['version'],
        'precio': prop['precio'].toString(),
        'total': prop['precio'].toString(),
        'cantidad': 1,
        'forma_pago': 'Efectivo',
      };
      await tx.insert('operation', {
        'scope': key,
        'uuid': uuid,
        'property_id': prop['id_propiedad'],
        'client_id': clientId,
        'payload': jsonEncode(payload),
        'status': 'local',
      });
    });
  }

  Future<void> synchronize(UserModel user) async {
    if (syncing) return;
    syncing = true;
    try {
      final db = await database;
      final pending = await db.query(
        'operation',
        where: "scope = ? AND status IN ('local','pendiente','enviando')",
        whereArgs: [scope(user)],
        orderBy: 'rowid',
      );
      for (final op in pending) {
        final args = [scope(user), op['uuid']];
        await db.update(
          'operation',
          {'status': 'enviando'},
          where: 'scope = ? AND uuid = ?',
          whereArgs: args,
        );
        try {
          final res = await dio.post<Map<String, dynamic>>(
            '/api/offline/sincronizar',
            data: jsonDecode(op['payload'] as String),
          );
          final result = res.data!;
          if (result['uuid'] != op['uuid'] ||
              ![
                'confirmada',
                'rechazada',
                'conflicto',
                'cancelada',
              ].contains(result['estado'])) {
            throw StateError('Respuesta no reconocida.');
          }
          await db.update(
            'operation',
            {
              'status': result['estado'],
              'message': result['motivo'] ?? 'Confirmada por el servidor.',
              'result': jsonEncode(result),
            },
            where: 'scope = ? AND uuid = ?',
            whereArgs: args,
          );
        } catch (error) {
          final detail = error is DioException ? error.response?.data : null;
          final message = detail is Map && detail['detail'] is String
              ? detail['detail'] as String
              : 'Sin confirmación. Se conserva para reintentar.';
          await db.update(
            'operation',
            {'status': 'pendiente', 'message': message},
            where: 'scope = ? AND uuid = ?',
            whereArgs: args,
          );
          break;
        }
      }
    } finally {
      syncing = false;
    }
  }

  Future<void> cancel(UserModel user, String uuid) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/api/offline/reservas/$uuid/cancelar',
    );
    final result = response.data!;
    if (result['uuid'] != uuid || result['estado'] != 'cancelada') {
      throw StateError('Cancelación sin confirmar.');
    }
    final db = await database;
    await db.update(
      'operation',
      {
        'status': 'cancelada',
        'message': result['motivo'],
        'result': jsonEncode(result),
      },
      where: 'scope = ? AND uuid = ?',
      whereArgs: [scope(user), uuid],
    );
  }
}

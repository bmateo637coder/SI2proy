import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/api_constants.dart';
import '../models/user_model.dart';
import 'local_reports.dart';
import 'reportes_service.dart';

class ReplicaStore extends ChangeNotifier {
  ReplicaStore({required this.user, this.databasePath});
  final UserModel? Function() user;
  final String? databasePath;
  Future<Database>? _db;
  bool online = true, downloading = false, syncing = false;
  int pending = 0, conflicts = 0;
  String? imagesStatus;
  String? lastDownload, message;
  int revision = 0;
  VoidCallback? onDataChanged;
  Future<List<Map<String, dynamic>>> Function()? legacyOperations;
  void emit() => notifyListeners();
  String? get account => user() == null
      ? null
      : '${ApiConstants.baseUrl}|${user()!.ci}|${user()!.idRol}|${user()!.idTenant}|${(List<String>.from(user()!.permisos)..sort()).join(",")}';
  Future<Database> get database => _db ??= _open();
  Future<Database> _open() async => openDatabase(
    databasePath ?? path.join(await getDatabasesPath(), 'raices_replica_v2.db'),
    version: 1,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE bundle(account TEXT PRIMARY KEY,data TEXT NOT NULL,updated TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE outbox(account TEXT NOT NULL,uuid TEXT PRIMARY KEY,payload TEXT NOT NULL,state TEXT NOT NULL,local_id INTEGER NOT NULL,target TEXT,result TEXT,integrated INTEGER NOT NULL DEFAULT 0,seen INTEGER NOT NULL DEFAULT 0)',
      );
      await db.execute(
        'CREATE INDEX outbox_account_state ON outbox(account,state)',
      );
      await db.execute(
        'CREATE TABLE cached_response(account TEXT NOT NULL,route TEXT NOT NULL,data TEXT NOT NULL,PRIMARY KEY(account,route))',
      );
    },
  );
  static Map<String, dynamic> clone(Map value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));
  static int installments(Map values) {
    if (values['num_cuotas'] != null) return values['num_cuotas'] as int;
    final start = LocalReports.day(values['fecha_inicio']),
        end = LocalReports.day(values['fecha_fin']);
    if (values['tipo_contrato'] == 'Alquiler' &&
        start != null &&
        end != null &&
        end.isAfter(start))
      return ((end.year - start.year) * 12 + end.month - start.month).clamp(
        1,
        36000,
      );
    return 1;
  }

  Future<Map<String, dynamic>?> raw({String? forAccount}) async {
    final key = forAccount ?? account;
    if (key == null) return null;
    final rows = await (await database).query(
      'bundle',
      where: 'account = ?',
      whereArgs: [key],
    );
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(jsonDecode(rows.first['data'] as String));
  }

  Future<void> save(Map<String, dynamic> bundle, String key) async {
    if (bundle['ci_usuario'] != user()?.ci || bundle['completo'] != true)
      throw StateError(
        'La descarga no corresponde a la cuenta o está incompleta.',
      );
    final db = await database;
    await db.transaction((tx) async {
      await tx.insert('bundle', {
        'account': key,
        'data': jsonEncode(bundle),
        'updated': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.update(
        'outbox',
        {'integrated': 1},
        where: "account = ? AND state = 'confirmada'",
        whereArgs: [key],
      );
    });
    if (key == account) {
      lastDownload = bundle['descargado_en']?.toString();
      revision++;
      onDataChanged?.call();
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> operations({String? key}) async {
    final a = key ?? account;
    if (a == null) return [];
    return (await database).query(
      'outbox',
      where: 'account = ?',
      whereArgs: [a],
      orderBy: 'rowid ASC',
    );
  }

  Future<void> counters() async {
    final list = await operations();
    final old = await legacyOperations?.call() ?? <Map<String, dynamic>>[];
    pending =
        list
            .where((r) => ['pendiente', 'enviando'].contains(r['state']))
            .length +
        old
            .where(
              (r) =>
                  ['local', 'pendiente', 'enviando'].contains(r['status']) ||
                  r['cancel_requested'] == 1,
            )
            .length;
    conflicts =
        list
            .where((r) => ['conflicto', 'rechazada'].contains(r['state']))
            .length +
        old
            .where((r) => ['conflicto', 'rechazada'].contains(r['status']))
            .length;
    lastDownload = (await raw())?['descargado_en']?.toString();
    notifyListeners();
  }

  Future<void> discard(String uuid) async {
    final db = await database;
    final removed = <String>{uuid};
    for (final row in await operations()) {
      final deps =
          (jsonDecode(row['payload'] as String)['dependencias'] as Map).values;
      if (deps.any(removed.contains)) removed.add(row['uuid'] as String);
    }
    for (final id in removed) {
      await db.update(
        'outbox',
        {'state': 'descartada'},
        where: 'account = ? AND uuid = ? AND state IN (?,?,?)',
        whereArgs: [account, id, 'conflicto', 'rechazada', 'pendiente'],
      );
    }
    revision++;
    onDataChanged?.call();
    await counters();
  }

  Future<Map<String, dynamic>> view({int? tenant}) async {
    final saved = await raw();
    if (saved == null)
      throw StateError(
        'La copia local aún no está preparada. Conéctate una vez para descargar los datos automáticamente.',
      );
    final data = clone(saved['datos'] as Map);
    final ops = await operations();
    for (final row in ops) {
      if (!['pendiente', 'enviando', 'confirmada'].contains(row['state']) ||
          row['integrated'] == 1)
        continue;
      final body = Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String),
      );
      for (final dep in (body['dependencias'] as Map).entries) {
        if (dep.key == 'base') continue;
        final parent = ops
            .where((r) => r['uuid'] == dep.value && r['state'] == 'confirmada')
            .firstOrNull;
        if (parent == null || parent['result'] == null) continue;
        final source =
            jsonDecode(parent['result'] as String)['data'] as Map? ?? {};
        final field = dep.key == 'id'
            ? ('${body['tipo']}'.startsWith('pago.') ||
                      body['tipo'] == 'contrato.eliminar'
                  ? 'id_contrato'
                  : 'id_propiedad')
            : dep.key;
        if (source[field] != null) {
          if (dep.key == 'id') {
            body['id'] = source[field];
          } else {
            body['datos'][dep.key] = source[field];
          }
        }
      }
      final id = row['local_id'] as int;
      final result = row['result'] == null
          ? null
          : jsonDecode(row['result'] as String);
      final authoritative = result?['data'];
      apply(
        data,
        body,
        id,
        authoritative is Map ? Map<String, dynamic>.from(authoritative) : null,
      );
    }
    final old = await legacyOperations?.call() ?? <Map<String, dynamic>>[];
    final captured = LocalReports.rows(
      data,
      'reservas',
    ).map((r) => r['uuid']).toSet();
    for (final row in old) {
      if (![
            'local',
            'pendiente',
            'enviando',
            'confirmada',
          ].contains(row['status']) ||
          captured.contains(row['uuid']))
        continue;
      final payload = jsonDecode(row['payload'] as String) as Map;
      final props = LocalReports.rows(data, 'propiedades');
      final prop = props
          .where(
            (p) =>
                p['id_propiedad'] == payload['id_propiedad'] &&
                p['id_tenant'] == payload['id_tenant'],
          )
          .firstOrNull;
      if (prop != null)
        prop.addAll({
          'estado': payload['tipo'] == 'reserva' ? 'Reservada' : 'Vendida',
          'pendiente_sync': true,
        });
      data['propiedades'] = props;
      data['reservas'] = [
        ...LocalReports.rows(data, 'reservas'),
        {...payload, 'estado': 'pendiente', 'pendiente_sync': true},
      ];
      if (payload['tipo'] == 'venta_contado') {
        final id = -int.parse(
          '${row['uuid']}'.replaceAll('-', '').substring(0, 12),
          radix: 16,
        );
        final amount = num.tryParse('${payload['total']}') ?? 0;
        final stamp = payload['registrado_en'].toString();
        final client = LocalReports.rows(
          data,
          'clientes',
        ).where((r) => r['id_cliente'] == payload['id_cliente']).firstOrNull;
        data['contratos'] = [
          ...LocalReports.rows(data, 'contratos'),
          {
            'id_contrato': id,
            'id_tenant': payload['id_tenant'],
            'id_cliente': payload['id_cliente'],
            'id_propiedad': payload['id_propiedad'],
            'cliente': client?['nombre'],
            'propiedad': prop?['titulo'],
            'inmobiliaria': prop?['inmobiliaria'],
            'agente': 'Sin agente',
            'tipo_contrato': 'Venta',
            'estado': 'Pagado',
            'monto_total': amount,
            'saldo_pendiente': 0,
            'fecha_inicio': stamp.split('T').first,
            'cuotas': [],
            'cuotas_totales': 1,
            'cuotas_pagadas': 1,
            'pagos': [
              {
                'id_pago': id,
                'monto': amount,
                'fecha_pago': stamp,
                'metodo_pago': 'Efectivo',
                'numero_recibo': 'LOCAL-${row['uuid']}',
                'pendiente_sync': true,
              },
            ],
            'pendiente_sync': true,
          },
        ];
      }
    }
    if (tenant != null) {
      for (final name in [
        'propiedades',
        'clientes',
        'propietarios',
        'agentes',
        'usuarios',
        'contratos',
        'sucursales',
        'reportes',
        'reservas',
      ]) {
        data[name] = LocalReports.rows(
          data,
          name,
        ).where((r) => r['id_tenant'] == tenant).toList();
      }
    }
    return data;
  }

  void apply(
    Map<String, dynamic> data,
    Map<String, dynamic> body,
    int localId,
    Map<String, dynamic>? confirmed,
  ) {
    final values = Map<String, dynamic>.from(body['datos']);
    final tid = body['id_tenant'];
    final props = LocalReports.rows(data, 'propiedades');
    final contacts = LocalReports.rows(data, 'clientes');
    final contracts = LocalReports.rows(data, 'contratos');
    final company =
        props
            .where((r) => r['id_tenant'] == tid)
            .firstOrNull?['inmobiliaria'] ??
        'Inmobiliaria $tid';
    final stamp =
        values['fecha_local'] ?? DateTime.now().toUtc().toIso8601String();
    switch (body['tipo']) {
      case 'cliente.crear':
        final person =
            LocalReports.rows(
              data,
              'usuarios',
            ).where((u) => u['ci'] == values['ci_usuario']).firstOrNull ??
            {};
        contacts.add(
          confirmed ??
              {
                ...person,
                ...values,
                'id_cliente': localId,
                'id_tenant': tid,
                'inmobiliaria': company,
                'pendiente_sync': true,
              },
        );
      case 'contrato.crear':
        final prop = props
            .where((p) => p['id_propiedad'] == values['id_propiedad'])
            .firstOrNull;
        final client = contacts
            .where((c) => c['id_cliente'] == values['id_cliente'])
            .firstOrNull;
        final count = installments(values);
        final total = num.tryParse('${values['monto_total']}') ?? 0;
        final cents = (total * 100).round(),
            base = (total * 100).round() ~/ count;
        contracts.add(
          confirmed ??
              {
                ...values,
                'id_contrato': localId,
                'id_tenant': tid,
                'inmobiliaria': company,
                'propiedad': prop?['titulo'],
                'cliente': client?['nombre'],
                'agente': '',
                'id_agente': prop?['id_agente'],
                'estado': 'Activo',
                'saldo_pendiente': total,
                'cuotas_totales': count,
                'cuotas_pagadas': 0,
                'pagos': [],
                'cuotas': List.generate(
                  count,
                  (i) => {
                    'id_cuota': -(i + 1),
                    'numero_cuota': i + 1,
                    'monto': (base + (i < cents % count ? 1 : 0)) / 100,
                    'fecha_vencimiento': DateTime.parse(values['fecha_inicio'])
                        .add(Duration(days: 30 * (i + 1)))
                        .toIso8601String()
                        .split('T')
                        .first,
                    'estado': 'Pendiente',
                  },
                ),
                'pendiente_sync': true,
              },
        );
        if (prop != null) prop['estado'] = 'Reservada';
      case 'pago.crear':
        final contract = contracts
            .where((c) => c['id_contrato'] == body['id'])
            .firstOrNull;
        if (contract != null) {
          final payments = List<dynamic>.from(contract['pagos'] ?? []);
          payments.add(
            confirmed ??
                {
                  ...values,
                  'id_pago': localId,
                  'numero_recibo': 'LOCAL-${body['uuid']}',
                  'fecha_pago': stamp,
                  'pendiente_sync': true,
                },
          );
          contract['pagos'] = payments;
          final paid = payments.fold<int>(
            0,
            (n, p) => n + ((num.tryParse('${p['monto']}') ?? 0) * 100).round(),
          );
          contract['saldo_pendiente'] =
              ((((num.tryParse('${contract['monto_total']}') ?? 0) * 100)
                          .round() -
                      paid)
                  .clamp(0, 999999999999)) /
              100;
          contract['estado'] = contract['saldo_pendiente'] == 0
              ? 'Pagado'
              : 'Activo';
          contract['pendiente_sync'] = true;
          var remainder = paid;
          var done = 0;
          for (final quota in contract['cuotas'] as List? ?? []) {
            final amount = ((num.tryParse('${quota['monto']}') ?? 0) * 100)
                .round();
            if (remainder >= amount) {
              quota['estado'] = 'Pagada';
              remainder -= amount;
              done++;
            }
          }
          contract['cuotas_pagadas'] = done;
          if (contract['estado'] == 'Pagado' &&
              contract['tipo_contrato'] == 'Venta') {
            final prop = props
                .where((p) => p['id_propiedad'] == contract['id_propiedad'])
                .firstOrNull;
            if (prop != null) prop['estado'] = 'Vendida';
          }
        }
      case 'contrato.eliminar':
        contracts.removeWhere((c) => c['id_contrato'] == body['id']);
      case 'reporte.guardar':
        data['reportes'] = [
          ...LocalReports.rows(data, 'reportes'),
          {
            ...(confirmed ??
                {
                  ...values,
                  'id_reporte': localId,
                  'fecha_creacion': stamp,
                  'pendiente_sync': true,
                }),
            'id_tenant': tid,
          },
        ];
      case 'propiedad.crear':
        props.add(
          confirmed ??
              {
                ...values,
                'id_propiedad': localId,
                'id_tenant': tid,
                'inmobiliaria': company,
                'estado': 'Disponible',
                'version': 1,
                'imagenes': [],
                'pendiente_sync': true,
              },
        );
      case 'propiedad.actualizar':
        final p = props
            .where((r) => r['id_propiedad'] == body['id'])
            .firstOrNull;
        if (p != null)
          p.addAll(confirmed ?? {...values, 'pendiente_sync': true});
      case 'propiedad.estado':
        final p = props
            .where((r) => r['id_propiedad'] == body['id'])
            .firstOrNull;
        if (p != null) p.addAll({...values, 'pendiente_sync': true});
      case 'propiedad.eliminar':
        props.removeWhere((r) => r['id_propiedad'] == body['id']);
    }
    data['propiedades'] = props;
    data['clientes'] = contacts;
    data['contratos'] = contracts;
  }

  static ({String type, int? id})? mutation(RequestOptions r) {
    final p = r.path;
    if (r.method == 'POST') {
      final type = {
        '/modulo_inmuebles/clientes': 'cliente.crear',
        '/gestion_contractual/contratos': 'contrato.crear',
        '/reportes/guardados': 'reporte.guardar',
        '/modulo_inmuebles/propiedades': 'propiedad.crear',
      }[p];
      if (type != null) return (type: type, id: null);
      final match = RegExp(r'^/gestion_contractual/contratos/(-?\d+)/pagos$')
          .firstMatch(p);
      if (match != null) return (type: 'pago.crear', id: int.parse(match[1]!));
    }
    final match = RegExp(
      r'^/(gestion_contractual/contratos|modulo_inmuebles/propiedades)/(-?\d+)(/estado)?$',
    ).firstMatch(p);
    if (match != null) {
      if (r.method == 'DELETE')
        return (
          type: match[1]!.contains('contratos')
              ? 'contrato.eliminar'
              : 'propiedad.eliminar',
          id: int.parse(match[2]!),
        );
      if (r.method == 'PUT' && match[1]!.contains('propiedades'))
        return (
          type: match[3] == null ? 'propiedad.actualizar' : 'propiedad.estado',
          id: int.parse(match[2]!),
        );
    }
    return null;
  }

  Future<Map<String, dynamic>> queue(RequestOptions request, int tenant) async {
    final spec = mutation(request);
    final identity = user();
    final key = account;
    if (spec == null ||
        identity == null ||
        key == null ||
        (identity.idRol != 1 && identity.idTenant != tenant) ||
        !identity.forTenant(tenant).canOperateOffline)
      throw StateError(
        'Esta operación necesita una cuenta operativa y una inmobiliaria concreta.',
      );
    if ((spec.type.startsWith('propiedad.') &&
                spec.type != 'propiedad.estado' ||
            spec.type == 'cliente.crear' ||
            spec.type == 'contrato.eliminar') &&
        !identity.isAdministrator)
      throw StateError('Solo un administrador puede realizar este cambio.');
    final before = await raw();
    if (before == null)
      throw StateError('Primero espera a que termine la descarga automática.');
    final data = Map<String, dynamic>.from(request.data as Map? ?? {});
    data['fecha_local'] = DateTime.now().toUtc().toIso8601String();
    final body = <String, dynamic>{
      'uuid': const Uuid().v4(),
      'id_tenant': tenant,
      'ci_usuario': identity.ci,
      'tipo': spec.type,
      'id': spec.id,
      'datos': data,
      'dependencias': <String, String>{},
    };
    final deps = body['dependencias'] as Map<String, String>;
    final existing = await operations();
    for (final field in ['id_cliente', 'id_propiedad', 'id']) {
      final id = field == 'id' ? spec.id : data[field];
      if (id is int && id < 0) {
        final parent = existing.where((r) => r['local_id'] == id).firstOrNull;
        if (parent == null)
          throw StateError('No se encontró el registro local relacionado.');
        deps[field] = parent['uuid'] as String;
      }
    }
    final target = spec.type == 'contrato.crear'
        ? 'propiedad:${data['id_propiedad']}'
        : spec.type == 'pago.crear' || spec.type == 'contrato.eliminar'
        ? 'contrato:${spec.id}'
        : spec.type.startsWith('propiedad.') && spec.id != null
        ? 'propiedad:${spec.id}'
        : null;
    if (target != null) {
      body['base'] = (before['huellas'] as Map?)?[target];
      final prior = existing
          .where(
            (r) =>
                r['target'] == target &&
                ['pendiente', 'enviando', 'confirmada'].contains(r['state']) &&
                r['integrated'] == 0,
          )
          .lastOrNull;
      if (prior != null) deps['base'] = prior['uuid'] as String;
    }
    final localId = -(DateTime.now().microsecondsSinceEpoch);
    final preview = await view(tenant: tenant);
    if (spec.type == 'cliente.crear') {
      if (!LocalReports.rows(
        preview,
        'usuarios',
      ).any((u) => u['ci'] == data['ci_usuario']))
        throw StateError(
          'El CI debe corresponder a un usuario descargado de esta inmobiliaria.',
        );
      if (LocalReports.rows(
        preview,
        'clientes',
      ).any((u) => u['ci_usuario'] == data['ci_usuario']))
        throw StateError('Este usuario ya está registrado como cliente.');
    }
    if (spec.type == 'pago.crear') {
      final c = LocalReports.rows(
        preview,
        'contratos',
      ).where((c) => c['id_contrato'] == spec.id).firstOrNull;
      final amount = num.tryParse('${data['monto']}') ?? 0;
      if (c == null ||
          !amount.isFinite ||
          num.parse(amount.toStringAsFixed(2)) != amount ||
          amount <= 0 ||
          amount > (num.tryParse('${c['saldo_pendiente']}') ?? 0) + 0.001)
        throw StateError(
          'El pago debe ser positivo y no superar el saldo local.',
        );
    }
    if (spec.type == 'contrato.crear') {
      final amount = num.tryParse('${data['monto_total']}');
      final count = installments(data);
      if (amount == null ||
          !amount.isFinite ||
          num.parse(amount.toStringAsFixed(2)) != amount ||
          amount <= 0 ||
          amount > 9999999999.99 ||
          count < 1 ||
          count > 360 ||
          (amount * 100).round() < count)
        throw StateError(
          'Revisa el monto positivo y el número de cuotas (1 a 360).',
        );
      final start = LocalReports.day(data['fecha_inicio']);
      final end = LocalReports.day(data['fecha_fin']);
      if (start == null || end != null && end.isBefore(start))
        throw StateError('Revisa las fechas del contrato.');
      if (!LocalReports.rows(
        preview,
        'clientes',
      ).any((c) => c['id_cliente'] == data['id_cliente']))
        throw StateError('El cliente no está disponible en esta inmobiliaria.');
      final p = LocalReports.rows(
        preview,
        'propiedades',
      ).where((p) => p['id_propiedad'] == data['id_propiedad']).firstOrNull;
      if (p == null ||
          p['estado'] != 'Disponible' ||
          p['tipo_operacion'] != data['tipo_contrato'])
        throw StateError(
          'La propiedad no está disponible para ese contrato en la copia local.',
        );
    }
    final db = await database;
    // Comprueba que la propuesta se puede representar antes de escribir la cola durable.
    apply(clone(preview), body, localId, null);
    if (key != account)
      throw StateError('Cambió la cuenta. Vuelve a abrir el formulario.');
    await db.insert('outbox', {
      'account': key,
      'uuid': body['uuid'],
      'payload': jsonEncode(body),
      'state': 'pendiente',
      'local_id': localId,
      'target': target,
    });
    revision++;
    onDataChanged?.call();
    await counters();
    final after = await view(tenant: tenant);
    if (spec.type == 'cliente.crear')
      return LocalReports.rows(
        after,
        'clientes',
      ).firstWhere((r) => r['id_cliente'] == localId);
    if (spec.type == 'contrato.crear')
      return LocalReports.rows(
        after,
        'contratos',
      ).firstWhere((r) => r['id_contrato'] == localId);
    if (spec.type == 'propiedad.crear')
      return LocalReports.rows(
        after,
        'propiedades',
      ).firstWhere((r) => r['id_propiedad'] == localId);
    if (spec.type == 'pago.crear')
      return {
        'id_pago': localId,
        'numero_recibo': 'LOCAL-${body['uuid']}',
        'saldo_pendiente': LocalReports.rows(
          after,
          'contratos',
        ).firstWhere((r) => r['id_contrato'] == spec.id)['saldo_pendiente'],
        'pendiente_sync': true,
      };
    return {
      'pendiente_sync': true,
      'mensaje':
          'Cambio guardado en el dispositivo. Se confirmará al sincronizar.',
    };
  }

  Future<dynamic> read(RequestOptions r, int? tenant) async {
    final data = await view(tenant: tenant);
    final routes = {
      '/modulo_inmuebles/propiedades': 'propiedades',
      '/modulo_inmuebles/propiedades/catalogo': 'propiedades',
      '/modulo_inmuebles/clientes': 'clientes',
      '/modulo_inmuebles/propietarios': 'propietarios',
      '/modulo_inmuebles/agentes': 'agentes',
      '/gestion_usuarios/usuarios': 'usuarios',
      '/gestion_contractual/contratos': 'contratos',
      '/api/saas/sucursales': 'sucursales',
      '/api/saas/planes': 'planes',
      '/roles': 'roles',
      '/reportes/guardados': 'reportes',
    };
    if (routes.containsKey(r.path)) {
      var result = LocalReports.rows(data, routes[r.path]!);
      if (r.path.endsWith('/catalogo'))
        result = result.where((p) => p['estado'] == 'Disponible').toList();
      return result;
    }
    final contract = RegExp(r'^/gestion_contractual/contratos/(-?\d+)$')
        .firstMatch(r.path);
    if (contract != null) {
      final row = LocalReports.rows(
        data,
        'contratos',
      ).where((c) => c['id_contrato'] == int.parse(contract[1]!)).firstOrNull;
      if (row == null)
        throw StateError('Contrato no disponible en esta copia local.');
      return row;
    }
    final receipt = RegExp(r'^/gestion_contractual/pagos/(-?\d+)/comprobante$')
        .firstMatch(r.path);
    if (receipt != null) {
      for (final c in LocalReports.rows(data, 'contratos')) {
        for (final p in c['pagos'] as List? ?? []) {
          if (p['id_pago'] == int.parse(receipt[1]!))
            return ReportesService.bytes(
              'pdf',
              ['Recibo', 'Monto', 'Método', 'Fecha', 'Cliente', 'Estado'],
              [
                {
                  'Recibo': p['numero_recibo'],
                  'Monto': p['monto'],
                  'Método': p['metodo_pago'],
                  'Fecha': p['fecha_pago'],
                  'Cliente': c['cliente'],
                  'Estado': p['pendiente_sync'] == true
                      ? 'PROVISIONAL - pendiente de confirmación'
                      : 'Copia local del pago confirmado',
                },
              ],
              title: 'Comprobante local · ${c['inmobiliaria']}',
            );
        }
      }
      throw StateError(
        'El comprobante aún no está disponible en el dispositivo.',
      );
    }
    final body = Map<String, dynamic>.from(r.data is Map ? r.data as Map : {});
    if (r.path == '/reportes/generar')
      return LocalReports.dynamicReport(data, body, tenant == null);
    if (r.path == '/api/analitica/convencional')
      return LocalReports.conventional(data, body, tenant == null);
    if (r.path == '/api/analitica/reporte')
      return LocalReports.conventional(
        data,
        LocalReports.naturalSpec('${body['texto']}'),
        tenant == null,
      );
    if (r.path == '/api/ia/estado')
      return {
        'configurada': false,
        'modelo': 'Herramientas locales',
        'plan_habilitado': true,
        'sin_conexion': true,
      };
    if (r.path == '/api/ia/reporte-voz') {
      final text = '${body['texto']}'.toLowerCase();
      final entity = text.contains('cliente')
          ? 'clientes'
          : text.contains('usuario')
          ? 'usuarios'
          : 'propiedades';
      return {
        'config': {
          'entidad': entity,
          'columnas': columnsFor(entity),
          'filtros': [
            if (text.contains('disponib') && entity == 'propiedades')
              {'columna': 'estado', 'operador': 'eq', 'valor': 'Disponible'},
          ],
          'orden': {
            'columna': entity == 'propiedades' ? 'precio' : 'nombre',
            'direccion': 'asc',
          },
        },
        'modo': 'reglas_locales',
      };
    }
    if (r.path == '/api/ia/recomendar')
      return {
        'recomendaciones': LocalReports.rows(data, 'propiedades')
            .where((p) => p['estado'] == 'Disponible')
            .take((body['limite'] as int?) ?? 5)
            .toList(),
        'modo': 'ranking_local',
      };
    if (r.path == '/api/ia/generar-descripcion')
      return {
        'descripcion':
            '${body['titulo']}, ubicada en ${body['direccion']}. Disponible para ${body['tipo_operacion']} por USD ${body['precio']}. Solicita información para coordinar una visita.',
        'modo': 'plantilla_local',
      };
    if (r.path == '/api/ia/chat')
      return {
        'respuesta':
            'Consulta local: hay ${LocalReports.rows(data, 'propiedades').where((p) => p['estado'] == 'Disponible').length} propiedades disponibles y ${LocalReports.rows(data, 'contratos').length} contratos en la selección. Puedes consultar los reportes locales para obtener filtros y totales. El asistente generativo volverá al recuperar conexión.',
        'modo': 'consulta_local',
      };
    if (r.path.startsWith('/api/ia/'))
      throw StateError(
        'La conexión real con Gemini se comprueba al recuperar Internet. Las herramientas locales siguen disponibles.',
      );
    final cached = await (await database).query(
      'cached_response',
      where: 'account = ? AND route = ?',
      whereArgs: [account, '${tenant ?? "all"}|${r.path}'],
    );
    if (cached.isNotEmpty) return jsonDecode(cached.first['data'] as String);
    throw StateError(
      'Esta función necesita conexión o una descarga previa. Los datos y reportes de la copia local siguen disponibles.',
    );
  }

  static List<String> columnsFor(String entity) =>
      LocalReports.columns[entity]!.where((c) => !c.startsWith('id_')).toList();
  Future<void> cache(RequestOptions r, dynamic data, int? tenant) async {
    final key = r.extra['replicaAccount'] as String? ?? account;
    if (key == null || key != account || data is! Map && data is! List) return;
    final db = await database;
    if (key != account) return;
    await db.insert('cached_response', {
      'account': key,
      'route': '${tenant ?? "all"}|${r.path}',
      'data': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

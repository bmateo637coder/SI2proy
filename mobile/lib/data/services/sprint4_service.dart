import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/api_constants.dart';
import '../../presentation/providers/auth_provider.dart';
import 'replica_store.dart';
import '../../core/utils/commercial_plan.dart';

class Sprint4Service extends ChangeNotifier {
  Sprint4Service(this.dio, this.auth, this.store) {
    auth.addListener(changed);
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    unawaited(refresh());
  }
  final Dio dio;
  final AuthProvider auth;
  final ReplicaStore store;
  Timer? timer;
  bool busy = false, offline = false, disposed = false;
  String? message;
  int pending = 0, conflicts = 0;
  DateTime? downloaded;
  String? lastAccount;
  Future<void>? initializing;
  String get identity =>
      '${ApiConstants.baseUrl}|${auth.user?.ci}|${auth.user?.idRol}|${(List<String>.from(auth.user?.permisos ?? [])..sort()).join(",")}|';
  String get account => '$identity${auth.scopeKey}';
  Object get scope =>
      auth.allTenants ? 'all' : auth.selectedTenant ?? auth.user?.idTenant ?? 0;
  bool get staff =>
      auth.user?.isAdministrator == true ||
      auth.user?.canOperateOffline == true;
  void emit() {
    if (!disposed) notifyListeners();
  }

  void changed() {
    if (lastAccount != account) {
      lastAccount = account;
      downloaded = null;
      pending = 0;
      conflicts = 0;
    }
    offline = auth.localSession || auth.needsOnlineLogin;
    emit();
    if (!auth.isLoading) unawaited(refresh());
  }

  Options options(Object scope) =>
      Options(extra: {'replicaBypass': true, 'tenantId': scope});
  Future<void> init() => initializing ??= () async {
    final db = await store.database;
    await db.execute(
      'CREATE TABLE IF NOT EXISTS s4_cache(account TEXT NOT NULL, route TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(account,route))',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS s4_queue(uuid TEXT PRIMARY KEY,identity TEXT NOT NULL,account TEXT NOT NULL,scope TEXT NOT NULL,command TEXT NOT NULL,local_id INTEGER NOT NULL,state TEXT NOT NULL,result TEXT,error TEXT)',
    );
  }();
  String route(String path, Map<String, dynamic>? params) =>
      '$path?${jsonEncode(params ?? {})}';
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? params,
    bool networkOnly = false,
  }) async {
    await init();
    final key = account, selected = scope;
    Future<dynamic> cached() async {
      final rows = await (await store.database).query(
        's4_cache',
        where: 'account=? AND route=?',
        whereArgs: [key, route(path, params)],
      );
      if (rows.isEmpty)
        throw StateError(
          'No se descargó esta información para esta cuenta e inmobiliaria. Conéctate una vez.',
        );
      offline = true;
      emit();
      return project(path, jsonDecode(rows.first['data'] as String), key);
    }

    if (RegExp(r'^/api/mantenimiento/-[0-9]+$').hasMatch(path)) {
      final id = int.parse(path.split('/').last);
      final rows = await (await store.database).query(
        's4_queue',
        where: 'account=? AND local_id=?',
        whereArgs: [key, id],
      );
      if (rows.isNotEmpty) {
        final data =
            jsonDecode(rows.first['command'] as String)['datos'] as Map;
        return {
          ...data,
          'id': id,
          'pendiente': true,
          'estado': 'Pendiente de sincronizar',
          'fotos': [],
          'costos': [],
          'historial': [],
          'costo_total': 0,
          'version': 0,
        };
      }
    }
    if (auth.localSession || auth.needsOnlineLogin) return cached();
    try {
      final r = await dio.get(
        path,
        queryParameters: params,
        options: options(selected),
      );
      if (account != key) throw StateError('La cuenta o inmobiliaria cambió.');
      await (await store.database).rawInsert(
        'INSERT OR REPLACE INTO s4_cache(account,route,data) VALUES(?,?,?)',
        [key, route(path, params), jsonEncode(r.data)],
      );
      offline = false;
      return await project(path, r.data, key);
    } on DioException catch (e) {
      if (networkOnly ||
          (e.response != null && (e.response!.statusCode ?? 0) < 500))
        rethrow;
      final rows = await (await store.database).query(
        's4_cache',
        where: 'account=? AND route=?',
        whereArgs: [key, route(path, params)],
      );
      if (rows.isEmpty)
        throw StateError(
          'No se descargó esta información para esta cuenta e inmobiliaria. Conéctate una vez.',
        );
      offline = true;
      emit();
      return project(path, jsonDecode(rows.first['data'] as String), key);
    }
  }

  Future<Map<String, dynamic>> mutate(
    String method,
    String path, [
    Map<String, dynamic> data = const {},
    int? version,
  ]) async {
    final key = account, owner = identity, selected = scope;
    await init();
    if (!auth.isAuthenticated || account != key)
      throw StateError(
        'La cuenta o inmobiliaria cambió. Vuelve a abrir la pantalla.',
      );
    final uuid = const Uuid().v4();
    final local = -DateTime.now().microsecondsSinceEpoch;
    final command = {
      'uuid': uuid,
      'metodo': method,
      'ruta': path,
      'datos': data,
      if (version != null && version > 0) 'version': version,
    };
    await (await store.database).insert('s4_queue', {
      'uuid': uuid,
      'identity': owner,
      'account': key,
      'scope': '$selected',
      'command': jsonEncode(command),
      'local_id': local,
      'state': 'pendiente',
    });
    pending++;
    emit();
    await flush();
    final rows = await (await store.database).query(
      's4_queue',
      where: 'uuid=?',
      whereArgs: [uuid],
    );
    final row = rows.first;
    if (row['state'] == 'conflicto')
      throw StateError(
        'El cambio requiere revisión en Sincronización de servicios.',
      );
    if (row['state'] == 'confirmado')
      return Map<String, dynamic>.from(jsonDecode(row['result'] as String));
    message = 'Cambio guardado en el teléfono; pendiente de sincronización.';
    emit();
    return {
      ...data,
      'id': local,
      'pendiente': true,
      'estado': 'Pendiente de sincronizar',
    };
  }

  Future<void> flush() async {
    if (busy ||
        !auth.isAuthenticated ||
        auth.isLoading ||
        auth.needsOnlineLogin ||
        auth.localSession)
      return;
    await init();
    busy = true;
    final owner = identity;
    try {
      final db = await store.database;
      final rows = await db.query(
        's4_queue',
        where: 'identity=? AND state=?',
        whereArgs: [owner, 'pendiente'],
        orderBy: 'local_id DESC',
      );
      for (final row in rows) {
        if (owner != identity || !auth.isAuthenticated) break;
        final command = Map<String, dynamic>.from(
          jsonDecode(row['command'] as String),
        );
        final match = RegExp(r'/-\d+').firstMatch(command['ruta'] as String);
        final dependency = command['datos']?['id_oportunidad'];
        if (dependency is int && dependency < 0) {
          final parent = await db.query(
            's4_queue',
            where: 'identity=? AND account=? AND local_id=?',
            whereArgs: [owner, row['account'], dependency],
          );
          if (parent.isEmpty || parent.first['state'] != 'confirmado') continue;
          command['datos']['id_oportunidad'] = jsonDecode(
            parent.first['result'] as String,
          )['id'];
        }
        if (match != null) {
          final local = int.parse(match.group(0)!.substring(1));
          final parent = await db.query(
            's4_queue',
            where: 'identity=? AND account=? AND local_id=?',
            whereArgs: [owner, row['account'], local],
          );
          if (parent.isEmpty || parent.first['state'] != 'confirmado') continue;
          final result = jsonDecode(parent.first['result'] as String);
          command['ruta'] = (command['ruta'] as String).replaceFirst(
            match.group(0)!,
            '/${result['id']}',
          );
        }
        try {
          final response = await dio.post(
            '/api/servicios/sync',
            data: command,
            options: options(row['scope']!),
          );
          if (owner != identity) break;
          await db.update(
            's4_queue',
            {
              'state': 'confirmado',
              'result': jsonEncode(response.data),
              'error': null,
            },
            where: 'uuid=?',
            whereArgs: [row['uuid']],
          );
        } on DioException catch (e) {
          if (e.response == null ||
              (e.response!.statusCode ?? 0) >= 500 ||
              e.response!.statusCode == 401) {
            offline = true;
            break;
          }
          await db.update(
            's4_queue',
            {'state': 'conflicto', 'error': jsonEncode(e.response!.data)},
            where: 'uuid=?',
            whereArgs: [row['uuid']],
          );
        }
      }
      final active = await db.query(
        's4_queue',
        where: 'identity=? AND state!=?',
        whereArgs: [owner, 'confirmado'],
      );
      pending = active.where((r) => r['state'] == 'pendiente').length;
      conflicts = active.where((r) => r['state'] == 'conflicto').length;
    } finally {
      busy = false;
      emit();
    }
  }

  Future<List<Map<String, Object?>>> changes() async {
    await init();
    return (await store.database).query(
      's4_queue',
      where: 'identity=? AND state!=?',
      whereArgs: [identity, 'confirmado'],
    );
  }

  Future<void> discard(String uuid) async {
    final db = await store.database;
    final rows = await db.query(
      's4_queue',
      where: 'identity=? AND uuid=?',
      whereArgs: [identity, uuid],
    );
    if (rows.isEmpty) return;
    final local = '/${rows.first['local_id']}';
    final children = await db.query(
      's4_queue',
      where: 'identity=? AND state!=?',
      whereArgs: [identity, 'confirmado'],
    );
    for (final r in children) {
      final path = jsonDecode(r['command'] as String)['ruta'] as String;
      if (r['uuid'] == uuid || path.contains(local))
        await db.delete(
          's4_queue',
          where: 'uuid=? AND identity=?',
          whereArgs: [r['uuid'], identity],
        );
    }
    await flush();
    emit();
  }

  Future<void> rebase(String uuid) async {
    final db = await store.database;
    final rows = await db.query(
      's4_queue',
      where: 'uuid=? AND identity=?',
      whereArgs: [uuid, identity],
    );
    if (rows.isEmpty || rows.first['error'] == null) return;
    final error = jsonDecode(rows.first['error'] as String);
    final detail = error is Map ? error['detail'] : null;
    final server = detail is Map ? detail['servidor'] : null;
    final version = server is Map ? server['version'] : null;
    if (version is! int)
      throw StateError(
        'Este cambio requiere corregir los datos o descartar la propuesta.',
      );
    final command = Map<String, dynamic>.from(
      jsonDecode(rows.first['command'] as String),
    );
    final next = const Uuid().v4();
    command['uuid'] = next;
    command['version'] = version;
    await db.update(
      's4_queue',
      {
        'uuid': next,
        'command': jsonEncode(command),
        'state': 'pendiente',
        'error': null,
      },
      where: 'uuid=? AND identity=?',
      whereArgs: [uuid, identity],
    );
    await flush();
  }

  Future<void> refresh() async {
    if (!disposed && auth.isAuthenticated && !auth.isLoading) {
      final active = await changes();
      pending = active.where((r) => r['state'] == 'pendiente').length;
      conflicts = active.where((r) => r['state'] == 'conflicto').length;
      emit();
    }
    if (disposed ||
        busy ||
        !auth.isAuthenticated ||
        auth.isLoading ||
        auth.localSession ||
        auth.needsOnlineLogin)
      return;
    await flush();
    if (downloaded != null &&
        DateTime.now().difference(downloaded!) < const Duration(minutes: 2))
      return;
    final key = account;
    final paths = [
      '/api/moneda',
      if (staff) '/api/predicciones',
      '/api/favoritos',
      '/api/alertas',
      '/api/recomendaciones',
      '/api/bandeja',
      '/api/visitas',
      '/api/mi-cuenta',
      '/api/mantenimiento',
      '/api/mantenimiento/mis-inmuebles',
      '/api/mantenimiento/costos/resumen',
      '/modulo_inmuebles/propiedades/catalogo',
      if (staff) ...[
        '/api/oportunidades',
        '/api/oportunidades/opciones',
        '/api/workflow-ia',
        '/api/gerencia/dashboard',
        '/api/analitica/zonas',
        '/api/comisiones',
        '/api/promociones',
        '/api/saas/planes',
      ],
      if (staff) '/api/reportes/ejecutivo',
      if (staff) '/modulo_inmuebles/clientes',
      if (staff && !auth.allTenants) '/api/saas/suscripcion',
      if (staff) '/api/saas/sucursales',
      if (auth.user?.canSeePropiedades == true) '/modulo_inmuebles/propiedades',
      if (auth.user?.canSeePropietarios == true)
        '/modulo_inmuebles/propietarios',
      if (auth.user?.canSeeAgentes == true) '/modulo_inmuebles/agentes',
      if (auth.user?.canSeeUsuarios == true) '/gestion_usuarios/usuarios',
      if (auth.user?.canSeeRoles == true) ...['/roles', '/permisos'],
      if (auth.isSuperAdmin) ...[
        '/admin/empresas',
        '/admin/vista-global/resumen',
        '/admin/backup/estado',
      ],
    ];
    for (final path in paths) {
      if (disposed || key != account) return;
      try {
        final value = await get(path, networkOnly: true);
        if (path == '/api/mantenimiento' && value is List) {
          for (final row in value) {
            if (key != account) return;
            await get('/api/mantenimiento/${row['id']}', networkOnly: true);
          }
        }
        if (path == '/api/analitica/zonas') {
          for (final metric in ['cierres', 'monto', 'precio_m2']) {
            if (key != account) return;
            await get(path, params: {'metrica': metric}, networkOnly: true);
          }
        }
      } catch (_) {
        // An optional service must not interrupt the rest of the download.
        continue;
      }
    }
    downloaded = DateTime.now();
    offline = false;
    emit();
  }

  @override
  void dispose() {
    disposed = true;
    timer?.cancel();
    auth.removeListener(changed);
    super.dispose();
  }

  Future<dynamic> project(String path, dynamic source, String key) async {
    if (source is! List ||
        ![
          '/api/favoritos',
          '/api/alertas',
          '/api/mantenimiento',
          '/api/visitas',
          '/api/oportunidades',
          '/api/workflow-ia',
        ].contains(path))
      return source;
    final rows = await (await store.database).query(
      's4_queue',
      where: 'account=? AND state=?',
      whereArgs: [key, 'pendiente'],
      orderBy: 'local_id DESC',
    );
    final result = List<dynamic>.from(jsonDecode(jsonEncode(source)));
    for (final row in rows) {
      final c = jsonDecode(row['command'] as String),
          route = c['ruta'] as String;
      if (path == '/api/favoritos' && route.startsWith('$path/')) {
        final id = int.tryParse(route.split('/').last);
        result.removeWhere((r) => r['id_propiedad'] == id);
        if (c['metodo'] == 'POST') {
          final cache = await (await store.database).query(
            's4_cache',
            where: 'account=? AND route=?',
            whereArgs: [
              key,
              this.route('/modulo_inmuebles/propiedades/catalogo', null),
            ],
          );
          if (cache.isNotEmpty) {
            final props = jsonDecode(cache.first['data'] as String) as List;
            final p = props.where((p) => p['id_propiedad'] == id).firstOrNull;
            if (p != null)
              result.add({
                'id_propiedad': id,
                'propiedad': p,
                'disponible': p['estado'] == 'Disponible',
                'pendiente': true,
              });
          }
        }
      } else if (route == path &&
          c['metodo'] == 'POST' &&
          ['/api/oportunidades', '/api/workflow-ia'].contains(path)) {
        result.add({
          ...c['datos'] as Map,
          'id': row['local_id'],
          'version': 1,
          'pendiente': true,
          'inmobiliaria': 'Inmobiliaria seleccionada',
          'historial': [],
          if (path == '/api/workflow-ia')
            ...localCommercialPlan(c['datos']['texto'] as String),
        });
      } else if (path == '/api/workflow-ia' &&
          route.startsWith('$path/') &&
          c['metodo'] == 'PUT') {
        final id = int.tryParse(route.split('/').last);
        final i = result.indexWhere((r) => r['id'] == id);
        if (i >= 0) {
          final item = result[i] as Map;
          final tasks = item['tareas'] as List;
          final task = c['datos']['tarea'] as int;
          if (task < tasks.length) {
            tasks[task]['completada'] = c['datos']['completada'];
            item['estado'] = tasks.every((t) => t['completada'] == true)
                ? 'Completado'
                : 'Pendiente';
            item['version'] = (item['version'] as int) + 1;
            item['pendiente'] = true;
          }
        }
      } else if (route == path && c['metodo'] == 'POST') {
        result.add({
          ...c['datos'] as Map,
          'id': row['local_id'],
          'id_visita': row['local_id'],
          'pendiente': true,
          'activa': true,
          'resumen': c['datos']['texto'] ?? 'Criterios guardados',
          'estado': 'Pendiente de sincronizar',
          'urgencia': 'Pendiente',
          'propiedad': 'Pendiente de sincronizar',
        });
      } else if (route.startsWith('$path/') &&
          !route.substring(path.length + 1).contains('/')) {
        final id = int.tryParse(route.split('/').last);
        if (c['metodo'] == 'DELETE') result.removeWhere((r) => r['id'] == id);
        if (c['metodo'] == 'PUT') {
          final i = result.indexWhere((r) => r['id'] == id);
          if (i >= 0)
            result[i] = {
              ...result[i] as Map,
              ...c['datos'] as Map,
              'version': ((result[i]['version'] as int?) ?? 0) + 1,
              'pendiente': true,
            };
        }
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> search(String text) async {
    if (!auth.localSession && !auth.needsOnlineLogin) {
      try {
        return Map<String, dynamic>.from(
          (await dio.post(
            '/api/busqueda-semantica',
            data: {'texto': text},
            options: options(scope),
          )).data,
        );
      } on DioException catch (e) {
        if (e.response != null && (e.response!.statusCode ?? 0) < 500) rethrow;
      }
    }
    final all = List<Map<String, dynamic>>.from(
      (await get('/modulo_inmuebles/propiedades/catalogo') as List).map(
        (p) => Map<String, dynamic>.from(p),
      ),
    );
    var t = text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    for (final n in {
      'dos': '2',
      'tres': '3',
      'cuatro': '4',
      'cinco': '5',
    }.entries)
      t = t.replaceAll(RegExp('\\b${n.key}\\b'), n.value);
    final maxMatch = RegExp(
      r'(?:hasta|menos de|maximo)\s*\$?\s*(\d+(?:[.,]\d+)*)\s*(mil|k|millones)?',
    ).firstMatch(t);
    double? maximum;
    if (maxMatch != null) {
      var number = maxMatch.group(1)!;
      if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(number))
        number = number.replaceAll(RegExp('[.,]'), '');
      maximum = double.tryParse(number.replaceAll(',', '.'));
      if (maximum != null && maxMatch.group(2) != null)
        maximum *= maxMatch.group(2) == 'millones' ? 1000000 : 1000;
    }
    final rooms = int.tryParse(
      RegExp(r'(\d+)\s*(habitacion|cuarto|dormitorio)')
              .firstMatch(t)
              ?.group(1) ??
          '',
    );
    final operation = t.contains('alquil')
        ? 'Alquiler'
        : t.contains('anticr')
        ? 'Anticretico'
        : RegExp(r'venta|compr').hasMatch(t)
        ? 'Venta'
        : null;
    final type = [
      'casa',
      'departamento',
      'local',
      'terreno',
      'oficina',
    ].where((x) => t.contains(x)).firstOrNull;
    final results = all.where((p) {
      if (p['estado'] != 'Disponible' ||
          operation != null && p['tipo_operacion'] != operation)
        return false;
      if (maximum != null && (num.tryParse('${p['precio']}') ?? 0) > maximum)
        return false;
      if (type != null && !'${p['titulo']}'.toLowerCase().contains(type))
        return false;
      if (rooms != null) {
        final attrs = List<Map>.from(p['caracteristicas'] ?? []);
        final value = attrs
            .where(
              (a) => [
                'cuartos',
                'habitaciones',
                'dormitorios',
              ].contains('${a['nombre']}'.toLowerCase()),
            )
            .firstOrNull;
        if (value == null || (num.tryParse('${value['valor']}') ?? 0) < rooms)
          return false;
      }
      return true;
    }).toList();
    offline = true;
    emit();
    return {
      'resultados': results,
      'resumen':
          'Filtros locales: ${operation ?? "cualquier operación"}${maximum != null ? ", hasta $maximum" : ""}${rooms != null ? ", $rooms habitaciones o más" : ""}',
      'modo': 'reglas_offline',
    };
  }

  Future<Map<String, dynamic>> ai(String action, int? id, String text) async {
    if (!auth.localSession && !auth.needsOnlineLogin) {
      try {
        return Map<String, dynamic>.from(
          (await dio.post(
            '/api/servicios/ia/$action',
            data: {'id_propiedad': id, 'texto': text},
            options: options(scope),
          )).data,
        );
      } on DioException catch (e) {
        if (e.response != null && (e.response!.statusCode ?? 0) < 500) rethrow;
      }
    }
    final props = await get('/modulo_inmuebles/propiedades/catalogo') as List;
    final p = props.where((p) => p['id_propiedad'] == id).firstOrNull;
    if (action != 'chat' && p == null)
      throw StateError(
        'El inmueble no está en la copia local de este alcance.',
      );
    return {
      'modo': 'asistente_local_offline',
      'respuesta': action == 'descripcion'
          ? '${p['titulo']}, en ${p['direccion']}. ${p['tipo_operacion']} por ${p['precio']}. ${p['descripcion'] ?? ""}'
          : action == 'cotizar'
          ? 'Precio publicado: ${p['precio']}. La tasación predictiva de este inmueble requiere consultar el modelo del servidor.'
          : 'Tu copia contiene ${props.length} inmuebles. Puedes buscar por operación, habitaciones y presupuesto, guardar favoritos y crear alertas. Los cambios se enviarán al recuperar conexión.',
    };
  }
}

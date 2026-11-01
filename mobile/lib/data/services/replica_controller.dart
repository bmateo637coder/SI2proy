import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../core/config/api_constants.dart';
import 'replica_store.dart';
import 'offline_service.dart';

bool unavailable(DioException error) =>
    error.type != DioExceptionType.cancel &&
    (error.response == null || (error.response!.statusCode ?? 0) >= 500);

class ReplicaInterceptor extends Interceptor {
  ReplicaInterceptor(this.store, this.auth);
  final ReplicaStore store;
  final AuthProvider auth;
  VoidCallback? onQueued;
  int? tenant(RequestOptions r) => r.headers['X-Tenant-Scope'] == 'all'
      ? null
      : int.tryParse('${r.headers['X-Tenant-ID'] ?? auth.user?.idTenant}');
  bool skip(RequestOptions r) =>
      r.extra['replicaBypass'] == true ||
      r.path.startsWith('/api/replica') ||
      r.path.startsWith('/api/offline') ||
      r.path.startsWith('/users/me') ||
      r.path == '/login' ||
      auth.user == null;
  Response<dynamic> response(RequestOptions r, dynamic data) => Response(
    requestOptions: r,
    data: data,
    statusCode: 200,
    extra: {'local': true},
  );
  @override
  Future<void> onRequest(
    RequestOptions r,
    RequestInterceptorHandler handler,
  ) async {
    if (skip(r)) {
      handler.next(r);
      return;
    }
    // Captura identidad/alcance antes de cualquier await: una respuesta anterior no se guarda para otra cuenta.
    r.extra['replicaAccount'] = store.account;
    try {
      if (ReplicaStore.mutation(r) != null) {
        final tid = tenant(r);
        if (tid == null || tid <= 0)
          throw StateError('Selecciona una inmobiliaria concreta.');
        final result = await store.queue(r, tid);
        onQueued?.call();
        handler.resolve(response(r, result));
        return;
      }
      final localRoutes = [
        '/modulo_inmuebles/propiedades/catalogo',
        '/modulo_inmuebles/propiedades',
        '/modulo_inmuebles/clientes',
        '/gestion_contractual/contratos',
        '/reportes/generar',
        '/reportes/guardados',
      ];
      final localReady =
          (r.method == 'GET' || r.path == '/reportes/generar') &&
          localRoutes.contains(r.path) &&
          await store.raw() != null;
      if (localReady ||
          !store.online ||
          auth.needsOnlineLogin ||
          (r.path.contains('/contratos/') &&
              RegExp(r'/-\d+').hasMatch(r.path))) {
        final data = await store.read(r, tenant(r));
        if (r.extra['replicaAccount'] != store.account)
          throw StateError('Cambió la cuenta. Vuelve a abrir esta pantalla.');
        handler.resolve(response(r, data));
        return;
      }
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: r,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: r,
            statusCode: 409,
            data: {
              'detail': error is StateError
                  ? error.message
                  : 'No se pudo guardar el cambio local.',
            },
          ),
        ),
      );
      return;
    }
    handler.next(r);
  }

  @override
  Future<void> onResponse(
    Response res,
    ResponseInterceptorHandler handler,
  ) async {
    if (!skip(res.requestOptions) &&
        res.extra['local'] != true &&
        res.requestOptions.extra['replicaAccount'] == store.account) {
      try {
        await store.cache(
          res.requestOptions,
          res.data,
          tenant(res.requestOptions),
        );
      } catch (_) {}
    }
    handler.next(res);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final r = error.requestOptions;
    if (!skip(r) &&
        unavailable(error) &&
        r.extra['replicaAccount'] == store.account) {
      store.online = false;
      store.emit();
      try {
        handler.resolve(response(r, await store.read(r, tenant(r))));
        return;
      } catch (_) {}
    }
    handler.next(error);
  }
}

class ReplicaController with WidgetsBindingObserver {
  ReplicaController(this.dio, this.auth, this.store, this.legacy);
  final Dio dio;
  final AuthProvider auth;
  final ReplicaStore store;
  final OfflineService legacy;
  Timer? timer;
  bool busy = false, disposed = false;
  bool imagesBusy = false;
  DateTime? lastRefresh;
  String? activeAccount;
  final images = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  void start() {
    activeAccount = store.account;
    store.legacyOperations = () async {
      final identity = auth.user;
      if (identity == null) return [];
      final tids = identity.idRol == 1
          ? auth.companies.map((c) => (c['id_tenant'] as num).toInt()).toList()
          : [identity.idTenant];
      return [
        for (final tid in tids)
          if (identity.forTenant(tid).canOperateOffline)
            ...await legacy.operations(identity.forTenant(tid)),
      ];
    };
    legacy.onChanged = () {
      store.counters();
      store.onDataChanged?.call();
      refresh(force: true);
    };
    auth.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    scheduleMicrotask(() => refresh(force: true));
  }

  void changed() {
    if (activeAccount != store.account) {
      activeAccount = store.account;
      lastRefresh = null;
      store.pending = 0;
      store.conflicts = 0;
      store.lastDownload = null;
      store.downloading = false;
      store.syncing = false;
      store.imagesStatus = null;
      store.message = null;
      store.emit();
    }
    if (auth.localSession) store.online = false;
    if (!disposed) scheduleMicrotask(() => refresh(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh(force: true);
  }

  Options options({Object? tenant}) => Options(
    extra: {'replicaBypass': true, if (tenant != null) 'tenantId': tenant},
    receiveTimeout: const Duration(seconds: 30),
  );
  Future<void> refresh({bool force = false}) async {
    if (busy || disposed || auth.user == null || auth.isLoading) return;
    busy = true;
    final identity = auth.user!;
    final key = store.account!;
    bool same() => !disposed && store.account == key;
    try {
      await store.counters();
      await dio.get(
        '/api/health',
        options: Options(
          extra: {'replicaBypass': true},
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      if (!same()) return;
      store.online = true;
      if (auth.needsOnlineLogin) {
        store.message = 'Hay conexión. Valida tu sesión para enviar los cambios pendientes.';
        return;
      }
      // La sesión del servidor valida permisos antes de cualquier subida; nunca se guardan contraseñas para reenviarlas.
      final verified = await dio.get('/users/me', options: options());
      if (!same()) return;
      await auth.validateServerProfile(
        Map<String, dynamic>.from(verified.data),
      );
      if (!same() || auth.needsOnlineLogin) return;
      store.syncing = true;
      store.emit();
      final db = await store.database;
      for (final row in await store.operations(key: key)) {
        if (!same() || !['pendiente', 'enviando'].contains(row['state']))
          continue;
        final body = Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String),
        );
        await db.update(
          'outbox',
          {'state': 'enviando'},
          where: 'account = ? AND uuid = ?',
          whereArgs: [key, row['uuid']],
        );
        try {
          final result = Map<String, dynamic>.from(
            (await dio.post(
              '/api/replica/cambios',
              data: body,
              options: options(tenant: body['id_tenant']),
            )).data,
          );
          if (result['uuid'] != row['uuid'] ||
              ![
                'confirmada',
                'rechazada',
                'conflicto',
              ].contains(result['estado']))
            throw StateError('Confirmación no reconocida.');
          await db.update(
            'outbox',
            {'state': result['estado'], 'result': jsonEncode(result)},
            where: 'account = ? AND uuid = ?',
            whereArgs: [key, row['uuid']],
          );
        } on DioException catch (error) {
          final terminal = [
            400,
            403,
            404,
            409,
            422,
          ].contains(error.response?.statusCode);
          await db.update(
            'outbox',
            {
              'state': terminal ? 'conflicto' : 'pendiente',
              'result': jsonEncode({
                'motivo': terminal
                    ? '${(error.response?.data as Map?)?['detail'] ?? 'Revisa permisos y datos del cambio.'}'
                    : 'Sin confirmación. Se conservará el mismo UUID para reintentar.',
              }),
            },
            where: 'account = ? AND uuid = ?',
            whereArgs: [key, row['uuid']],
          );
          if (!terminal) rethrow;
        }
      }
      if (!same()) return;
      final tenants = identity.idRol == 1
          ? auth.companies.map((c) => (c['id_tenant'] as num).toInt()).toList()
          : [identity.idTenant];
      bool legacyChanged = false;
      for (final tid in tenants) {
        if (!identity.forTenant(tid).canOperateOffline) continue;
        final old = await legacy.operations(identity.forTenant(tid));
        if (old.any(
          (r) =>
              ['local', 'pendiente', 'enviando'].contains(r['status']) ||
              r['cancel_requested'] == 1,
        )) {
          legacyChanged = true;
          await legacy.synchronize(identity.forTenant(tid));
        }
      }
      final shouldDownload =
          force ||
          legacyChanged ||
          lastRefresh == null ||
          DateTime.now().difference(lastRefresh!) >
              const Duration(minutes: 1) ||
          store.pending > 0;
      if (shouldDownload) {
        store.downloading = true;
        store.message = 'Preparando la copia local de todas las pantallas…';
        store.emit();
        final scope = identity.idRol == 1 ? 'all' : identity.idTenant;
        final result = Map<String, dynamic>.from(
          (await dio.get(
            '/api/replica/datos',
            options: options(tenant: scope),
          )).data,
        );
        if (!same()) return;
        await store.save(result, key);
        lastRefresh = DateTime.now();
        // Catálogos operativos antiguos también quedan listos sin un botón de descarga.
        for (final tid in tenants) {
          if (!same()) return;
          try {
            await legacy.download(identity.forTenant(tid));
          } on DioException catch (error) {
            if (unavailable(error)) rethrow;
          }
          try {
            final response = await dio.get(
              '/api/analitica/dashboard',
              options: options(tenant: tid),
            );
            await store.cache(response.requestOptions, response.data, tid);
          } on DioException catch (error) {
            if (unavailable(error)) rethrow;
          }
        }
        if (identity.idRol == 1) {
          try {
            final r = await dio.get(
              '/api/analitica/dashboard',
              options: options(tenant: 'all'),
            );
            await store.cache(r.requestOptions, r.data, null);
          } on DioException catch (error) {
            if (unavailable(error)) rethrow;
          }
        }
        await store.counters();
        store.message = store.conflicts > 0
            ? 'Hay ${store.conflicts} cambios que necesitan revisión. No se sobrescribieron los datos del servidor.'
            : 'Copia local actualizada. Puedes seguir trabajando sin Internet.';
        unawaited(prefetchImages(result, key));
      }
    } on DioException catch (error) {
      if (same()) {
        if (unavailable(error)) {
          store.online = false;
          store.message = (await store.raw()) == null
              ? 'Sin conexión. La primera preparación necesita Internet.'
              : 'Sin conexión: estás trabajando con la copia local.';
        } else if (error.response?.statusCode == 401)
          store.message =
              'Valida tu sesión para sincronizar. Tus cambios siguen guardados.';
        else
          store.message =
              'No se pudo completar la actualización: ${(error.response?.data is Map) ? error.response?.data['detail'] ?? 'reintenta al recuperar conexión' : 'reintenta al recuperar conexión'}';
      }
    } catch (_) {
      if (same()) store.message = 'La actualización no terminó; se conserva la última copia completa y los cambios pendientes.';
    } finally {
      busy = false;
      if (same()) {
        store.downloading = false;
        store.syncing = false;
        await store.counters();
        store.emit();
      } else if (!disposed && auth.user != null) {
        store.downloading = false;
        store.syncing = false;
        lastRefresh = null;
        scheduleMicrotask(() => refresh(force: true));
      }
    }
  }

  static Future<File?> imageFile(String key, String url) async {
    final dir = await getApplicationSupportDirectory();
    final digest = crypto.sha256.convert(utf8.encode('$key|$url'));
    final file = File('${dir.path}/replica_images/$digest');
    return file;
  }

  Future<void> prefetchImages(Map<String, dynamic> bundle, String key) async {
    if (imagesBusy) return;
    imagesBusy = true;
    var failures = 0;
    final props = (bundle['datos']['propiedades'] as List? ?? []);
    if (key == store.account) {
      store.imagesStatus = 'Preparando fotos para usarlas sin conexión…';
      store.emit();
    }
    try {
      for (final p in props) {
        for (final item in p['imagenes'] as List? ?? []) {
          if (disposed || key != store.account) return;
          final raw = item is Map ? item['url'].toString() : item.toString();
          final uri = Uri.parse(ApiConstants.baseUrl).resolve(raw);
          if (!['http', 'https'].contains(uri.scheme)) continue;
          try {
            final file = (await imageFile(key, uri.toString()))!;
            if (await file.exists()) continue;
            await file.parent.create(recursive: true);
            final token = CancelToken();
            await images.download(
              uri.toString(),
              '${file.path}.part',
              cancelToken: token,
              onReceiveProgress: (count, total) {
                if (count > 8 * 1024 * 1024)
                  token.cancel('Imagen demasiado grande');
              },
            );
            await File('${file.path}.part').rename(file.path);
          } catch (_) {
            failures++;
          }
        }
      }
    } finally {
      imagesBusy = false;
      if (key == store.account) {
        store.imagesStatus = failures == 0
            ? 'Fotos preparadas para consultar sin conexión.'
            : '$failures fotos no pudieron descargarse. Se reintentará automáticamente.';
        store.emit();
      }
    }
  }

  void dispose() {
    disposed = true;
    timer?.cancel();
    auth.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    images.close(force: true);
    legacy.onChanged = null;
    store.legacyOperations = null;
  }
}

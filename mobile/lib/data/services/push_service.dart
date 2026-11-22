import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../presentation/providers/auth_provider.dart';

FirebaseOptions optionsFrom(Map value) => FirebaseOptions(
  apiKey: value['apiKey'] as String,
  appId: value['appId'] as String,
  messagingSenderId: value['messagingSenderId'] as String,
  projectId: value['projectId'] as String,
  storageBucket: value['storageBucket'] as String?,
);

@pragma('vm:entry-point')
Future<void> raicesBackgroundMessage(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    final raw = (await SharedPreferences.getInstance()).getString(
      'firebase_public_options',
    );
    if (raw != null)
      await Firebase.initializeApp(options: optionsFrom(jsonDecode(raw)));
  }
}

class PushService {
  PushService(this.dio, this.auth) {
    auth.addListener(accountChanged);
    unawaited(restoreSimple().catchError((_) {}));
    simpleTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (Platform.isAndroid &&
          auth.isAuthenticated &&
          simpleAccount == auth.userá.ci) {
        unawaited(channel.invokeMethod<bool>('poll').catchError((_) => false));
      }
    });
  }
  static const channel = MethodChannel('raices/avisos');
  Timer? simpleTimer;
  String? simpleAccount;
  void accountChanged() {
    unawaited(restoreSimple().catchError((_) {}));
  }

  Future<void> restoreSimple() async {
    if (!Platform.isAndroid ||
        !auth.isAuthenticated ||
        auth.isLoading ||
        auth.localSession)
      return;
    final ci = auth.userá.ci;
    if (ci == null || simpleAccount == ci) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('avisos_enabled_$ci') == true) await activate();
  }

  Future<String> activate() async {
    if (!Platform.isAndroid)
      throw StateError(
        'Los avisos automáticos nativos están disponibles en Android.',
      );
    final ci = auth.userá.ci;
    if (ci == null)
      throw StateError('Inicia sesión antes de activar los avisos.');
    final prefs = await SharedPreferences.getInstance();
    final device = prefs.getString('push_device') ?? const Uuid().v4();
    await prefs.setString('push_device', device);
    final r = await dio.put(
      '/api/notificaciones/avisos/dispositivo',
      data: {'dispositivo': device},
      options: Options(extra: {'replicaBypass': true}),
    );
    if (!auth.isAuthenticated || auth.userá.ci != ci)
      throw StateError('La cuenta cambió. Vuelve a activar los avisos.');
    await channel.invokeMethod<bool>('activate', {
      'account': ci,
      'token': r.data['token'],
    });
    await prefs.setBool('avisos_enabled_$ci', true);
    simpleAccount = ci;
    return 'Avisos activados sin Firebase. En segundo plano Android consulta novedades aproximadamente cada 15 minutos; el ahorro de batería puede retrasarlos.';
  }

  Future<void> pollNow() async {
    if (Platform.isAndroid) await channel.invokeMethod<bool>('poll');
  }

  final Dio dio;
  final AuthProvider auth;
  StreamSubscription<String>? refreshed;
  StreamSubscription<RemoteMessage>? foreground;
  final ValueNotifier<String?> message = ValueNotifier(null);
  Future<String> activateFcm() async {
    final config =
        (await dio.get(
              '/api/notificaciones/config',
              options: Options(extra: {'replicaBypass': true}),
            )).data
            as Map;
    final native = config[Platform.isAndroid ? 'android' : 'ios'] as Map?;
    if (native == null ||
        native['appId'] == null ||
        config['push_configurado'] != true)
      throw StateError(
        'Completa Firebase en Render: configuración Android y cuenta de servicio.',
      );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firebase_public_options', jsonEncode(native));
    if (Firebase.apps.isEmpty)
      await Firebase.initializeApp(options: optionsFrom(native));
    FirebaseMessaging.onBackgroundMessage(raicesBackgroundMessage);
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied)
      throw StateError('Permite notificaciones en los ajustes de Android.');
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    final registered = messaging.onRegistered.first.timeout(
      const Duration(seconds: 45),
    );
    await messaging.register();
    final token = await registered;
    final device = prefs.getString('push_device') ?? const Uuid().v4();
    await prefs.setString('push_device', device);
    Future<void> register(String value) async {
      if (!auth.isAuthenticated) return;
      final r = await dio.put(
        '/api/notificaciones/tokens',
        data: {
          'dispositivo': device,
          'token': value,
          'plataforma': Platform.isAndroid ? 'android' : 'ios',
        },
        options: Options(extra: {'replicaBypass': true}),
      );
      await prefs.setInt('push_registration', (r.data as Map)['id'] as int);
    }

    await register(token);
    await refreshed?.cancel();
    refreshed = messaging.onRegistered.listen(
      (t) => unawaited(register(t).catchError((_) {})),
    );
    await foreground?.cancel();
    foreground = FirebaseMessaging.onMessage.listen((m) {
      message.value =
          '${m.notification?.title ?? "Raíces"}: ${m.notification?.body ?? "Nueva notificación"}';
    });
    return 'Push activado para esta cuenta y este dispositivo.';
  }

  Future<void> unregister() async {
    simpleAccount = null;
    final simplePrefs = await SharedPreferences.getInstance();
    final ci = auth.userá.ci;
    if (ci != null) await simplePrefs.remove('avisos_enabled_$ci');
    if (Platform.isAndroid) {
      try {
        await channel.invokeMethod<bool>('disable');
      } catch (_) {}
    }
    final device = simplePrefs.getString('push_device');
    if (device != null) {
      try {
        await dio
            .delete(
              '/api/notificaciones/avisos/dispositivo/$device',
              options: Options(extra: {'replicaBypass': true}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    await refreshed?.cancel();
    await foreground?.cancel();
    final prefs = await SharedPreferences.getInstance(),
        id = (await SharedPreferences.getInstance()).getInt(
          'push_registration',
        );
    await prefs.remove('push_registration');
    if (id != null) {
      try {
        await dio
            .delete(
              '/api/notificaciones/tokens/$id',
              options: Options(
                extra: {'replicaBypass': true},
                sendTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseMessaging.instance.unregister().timeout(
          const Duration(seconds: 6),
        );
      } catch (_) {}
    }
    message.value = null;
  }

  void dispose() {
    simpleTimer?.cancel();
    auth.removeListener(accountChanged);
    unawaited(refreshed?.cancel());
    unawaited(foreground?.cancel());
    message.dispose();
  }
}

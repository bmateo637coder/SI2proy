import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
  PushService(this.dio, this.auth);
  final Dio dio;
  final AuthProvider auth;
  StreamSubscription<String>? refreshed;
  StreamSubscription<RemoteMessage>? foreground;
  final ValueNotifier<String?> message = ValueNotifier(null);
  Future<String> activate() async {
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
    await refreshed?.cancel();
    await foreground?.cancel();
    final prefs = await SharedPreferences.getInstance(),
        id = (await SharedPreferences.getInstance()).getInt(
          'push_registration',
        );
    await prefs.remove('push_registration');
    if (id != null) {
      try {
        await dio.delete(
          '/api/notificaciones/tokens/$id',
          options: Options(extra: {'replicaBypass': true}),
        );
      } catch (_) {}
    }
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseMessaging.instance.unregister();
      } catch (_) {}
    }
    message.value = null;
  }

  void dispose() {
    unawaited(refreshed?.cancel());
    unawaited(foreground?.cancel());
    message.dispose();
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inmobiliaria_mobile/data/services/sprint4_service.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';
import 'package:inmobiliaria_mobile/presentation/screens/servicios_screen.dart';

import 'workspace_parity_test.dart' show WorkspaceAuth, WorkspaceService;

class DelayedService extends WorkspaceService {
  DelayedService(super.d, super.a);
  final requests = <String, Completer<dynamic>>{};
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? params,
    bool networkOnly = false,
  }) => (requests[path] ??= Completer<dynamic>()).future;
}

void main() {
  testWidgets('a late response cannot replace the newly selected service', (
    tester,
  ) async {
    final dio = Dio();
    final auth = WorkspaceAuth(dio);
    final service = DelayedService(dio, auth);
    addTearDown(service.dispose);
    addTearDown(auth.dispose);
    Widget app(String section) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<Sprint4Service>.value(value: service),
      ],
      child: MaterialApp(home: ServiciosScreen(initialSection: section)),
    );
    await tester.pumpWidget(app('Favoritos'));
    await tester.pump();
    expect(service.requests.containsKey('/api/favoritos'), isTrue);
    await tester.pumpWidget(app('Alertas'));
    await tester.pump();
    expect(service.requests.containsKey('/api/alertas'), isTrue);
    service.requests['/api/alertas']!.complete([]);
    await tester.pumpAndSettle();
    // A malformed-for-Alertas old response would cause a build exception if applied.
    service.requests['/api/favoritos']!.complete({'old': 'response'});
    await tester.pumpAndSettle();
    expect(find.text('Alertas'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

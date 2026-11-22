import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inmobiliaria_mobile/data/services/sprint4_service.dart';
import 'package:inmobiliaria_mobile/presentation/providers/auth_provider.dart';
import 'package:inmobiliaria_mobile/presentation/screens/market_tools_screen.dart';

import 'workspace_parity_test.dart' show WorkspaceAuth, WorkspaceService;

class MarketService extends WorkspaceService {
  MarketService(super.d, super.a);
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? params,
    bool networkOnly = false,
  }) async {
    if (path == '/api/moneda')
      return {
        'tasas': {
          'USD': '1',
          'BOB': '6.96',
          'EUR': '0.9',
          'BRL': '5',
          'CLP': '900',
          'PEN': '3.7',
        },
        'actualizado_en': '2026-11-22T00:00:00Z',
        'proxima_actualizacion_unix': 9999999999,
        'vencidas': false,
        'fuente': 'Test provider',
        'fuente_url': 'https://example.test',
        'aviso': 'Referencia',
      };
    final demo = params?['modo'] == 'demo';
    Map<String, dynamic> series() => {
      'estado': demo ? 'calculado' : 'historial_insuficiente',
      'eventos': demo ? 120 : 0,
      'meses_entrenamiento': demo ? 24 : 0,
      'modelo': 'Ridge',
      'mae_validacion': 0.3,
      'mae_base': 1.1,
      'mae_modelo_ml': 0.3,
      'historial': [],
      'proyeccion': demo
          ? [
              for (var i = 1; i <= 6; i++)
                {'mes': '2027-0$i', 'cantidad': 5 + i},
            ]
          : [],
    };
    return {
      'modo': demo ? 'demo' : 'real',
      'generado_en': '2026-11-22',
      'hasta': '2026-10',
      'advertencia': demo
          ? 'Escenario sintético académico'
          : 'Historial insuficiente',
      'definiciones': {
        'ventas': 'Contratos de venta',
        'demanda': 'Visitas no canceladas',
      },
      'ventas': series(),
      'demanda': series(),
    };
  }
}

void main() {
  Future<void> app(WidgetTester tester, {bool predictions = false}) async {
    final dio = Dio(), auth = WorkspaceAuth(Dio());
    final service = MarketService(dio, auth);
    addTearDown(service.dispose);
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<Sprint4Service>.value(value: service),
        ],
        child: MaterialApp(home: MarketToolsScreen(predictions: predictions)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'currency screen converts on a narrow phone and swaps currencies',
    (tester) async {
      await app(tester);
      expect(find.text('696.00 BOB'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '150');
      await tester.pumpAndSettle();
      expect(find.text('1044.00 BOB'), findsOneWidget);
      await tester.tap(find.byTooltip('Invertir monedas'));
      await tester.pumpAndSettle();
      expect(find.text('21.55 USD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'prediction screen identifies insufficient history and explicit demo',
    (tester) async {
      await app(tester, predictions: true);
      expect(find.textContaining('Historial insuficiente.'), findsWidgets);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escenario académico').last);
      await tester.pumpAndSettle();
      expect(find.text('DEMOSTRACIÓN · DATOS SINTÉTICOS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

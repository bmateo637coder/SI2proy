import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android registra el servicio de avisos y exige una cuenta activa',
    (tester) async {
      const channel = MethodChannel('raices/avisos');
      await channel.invokeMethod<bool>('disable');
      expect(await channel.invokeMethod<bool>('status'), isFalse);
      await expectLater(
        channel.invokeMethod<bool>('activate', {'account': '', 'token': ''}),
        throwsA(isA<PlatformException>()),
      );
      expect(await channel.invokeMethod<bool>('status'), isFalse);
    },
  );
}

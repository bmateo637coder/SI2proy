import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inmobiliaria_mobile/data/models/propiedad_model.dart';
import 'package:inmobiliaria_mobile/presentation/widgets/raices_map.dart';

void main() {
  test('map excludes invalid coordinates without inventing positions', () {
    for (final pair in [
      [null, -63],
      ['', -63],
      [double.nan, 0],
      [0, double.infinity],
      [91, 0],
      [86, 0],
      [0, 181],
    ]) {
      expect(mapCoordinate(pair[0], pair[1]), isNull);
    }
    expect(mapCoordinate('-17.78', '-63.18')!.latitude, -17.78);
    expect(mapCoordinate(0, 0)!.longitude, 0);
  });
  test(
    'property serialization preserves offline location and full details',
    () {
      final input = {
        'id_propiedad': 1,
        'id_tenant': 2,
        'titulo': 'Casa',
        'descripcion': 'Con jardín',
        'inmobiliaria': 'Horizonte',
        'latitud': -17.78,
        'longitud': -63.18,
        'caracteristicas': [
          {'nombre': 'Cuartos', 'valor': '3'},
        ],
        'imagenes': [
          {'id_imagen': 2, 'url': 'https://example.test/foto.jpg'},
        ],
      };
      final restored = PropiedadModel.fromJson(
        PropiedadModel.fromJson(input).toJson(),
      );
      expect(restored.latitud, -17.78);
      expect(restored.longitud, -63.18);
      expect(restored.descripcion, 'Con jardín');
      expect(restored.inmobiliaria, 'Horizonte');
      expect(restored.caracteristicas.single['valor'], '3');
      expect(restored.imagenes.single.url, 'https://example.test/foto.jpg');
    },
  );
  testWidgets('empty map explains missing coordinates on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RaicesMap(points: [])),
      ),
    );
    expect(
      find.text('Sin ubicaciones válidas para este filtro.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:inmobiliaria_mobile/core/utils/currency_math.dart';

void main() {
  test('decimal conversion, inverse, cross-rate and half-up rounding', () {
    expect(currencyConvert('100', '1', '6.96'), '696.00');
    expect(currencyConvert('696', '6.96', '1'), '100.00');
    expect(currencyConvert('90', '0.9', '6.96'), '696.00');
    expect(currencyConvert('0.105', '1', '1'), '0.11');
    expect(currencyConvert('1.005', '1', '1'), '1.01');
  });
  test('invalid or out-of-range values never produce a result', () {
    for (final value in ['NaN', 'Infinity', '-1', '1000000000001', ''])
      expect(currencyConvert(value, '1', '6.96'), isNull);
    expect(currencyConvert('100', '0', '6.96'), isNull);
  });
}

/// Decimal cross-rate conversion with integer arithmetic and half-up rounding.
String? currencyConvert(String amount, String origin, String target) {
  (BigInt, BigInt)? fraction(String value) {
    final match = RegExp(r'^(\d{1,15})(?:\.(\d{0,12}))?$')
        .firstMatch(value.trim().replaceAll(',', '.'));
    if (match == null) return null;
    final decimals = match[2] ?? '';
    return (
      BigInt.parse('${match[1]}$decimals'),
      BigInt.from(10).pow(decimals.length),
    );
  }

  final a = fraction(amount), from = fraction(origin), to = fraction(target);
  if (a == null ||
      from == null ||
      to == null ||
      from.$1 <= BigInt.zero ||
      to.$1 <= BigInt.zero ||
      a.$1 > BigInt.from(1000000000000) * a.$2)
    return null;
  final numerator = a.$1 * to.$1 * from.$2;
  final denominator = a.$2 * to.$2 * from.$1;
  final cents =
      (numerator * BigInt.from(200) + denominator) ~/
      (BigInt.two * denominator);
  return '${cents ~/ BigInt.from(100)}.${(cents % BigInt.from(100)).toString().padLeft(2, '0')}';
}

/** Integer arithmetic: decimal input, cross-rates and half-up cent rounding. */
export function currencyConvert(amount: string, origin: unknown, target: unknown): string | null {
  const fraction = (value: unknown): [bigint, bigint] | null => {
    if (typeof value !== 'string' && typeof value !== 'number') return null;
    const match = /^(\d{1,15})(?:\.(\d{0,12}))?$/.exec(String(value).trim().replace(',', '.'));
    if (!match) return null;
    return [BigInt(match[1] + (match[2] || '')), 10n ** BigInt((match[2] || '').length)];
  };
  const a = fraction(amount), from = fraction(origin), to = fraction(target);
  if (!a || !from || !to || from[0] <= 0n || to[0] <= 0n || a[0] > 1000000000000n * a[1]) return null;
  const numerator = a[0] * to[0] * from[1];
  const denominator = a[1] * to[1] * from[0];
  const cents = (numerator * 200n + denominator) / (2n * denominator);
  return `${cents / 100n}.${String(cents % 100n).padStart(2, '0')}`;
}

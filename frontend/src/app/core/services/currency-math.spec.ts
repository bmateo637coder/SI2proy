import { currencyConvert } from './currency-math';
describe('Decimal currency conversion',()=>{
  it('converts forward, reverse and cross rates without binary rounding errors',()=>{
    expect(currencyConvert('100','1','6.96')).toBe('696.00');
    expect(currencyConvert('696','6.96','1')).toBe('100.00');
    expect(currencyConvert('90','.9','6.96')).toBe(null); // Input requires a leading zero.
    expect(currencyConvert('90','0.9','6.96')).toBe('696.00');
    expect(currencyConvert('0.105','1','1')).toBe('0.11');
    expect(currencyConvert('1.005','1','1')).toBe('1.01');
  });
  it('rejects missing, non-finite and negative amounts/rates',()=>{
    for(const value of ['NaN','Infinity','-1','1000000000001',''])expect(currencyConvert(value,'1','6.96')).toBeNull();
    expect(currencyConvert('100',undefined,'6.96')).toBeNull();
    expect(currencyConvert('100','0','6.96')).toBeNull();
  });
});

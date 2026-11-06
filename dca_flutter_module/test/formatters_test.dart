import 'package:dca_flutter_module/src/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatMoney', () {
    expect(formatMoney(0), '0');
    expect(formatMoney(999), '999');
    expect(formatMoney(1000), '1,000');
    expect(formatMoney(1500000), '1,500,000');
  });

  test('parseMoney', () {
    expect(parseMoney(''), isNull);
    expect(parseMoney('1,500,000'), 1500000);
  });

  test('ThousandsSeparatorInputFormatter', () {
    const f = ThousandsSeparatorInputFormatter();
    TextEditingValue type(String text) => f.formatEditUpdate(
        TextEditingValue.empty, TextEditingValue(text: text));

    expect(type('1000000').text, '1,000,000');
    expect(type('00012a3').text, '123');
    expect(type('abc').text, '');
  });
}

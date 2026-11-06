import 'package:flutter/services.dart';

final _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');
final _nonDigit = RegExp(r'\D');

/// 1500000 -> "1,500,000" (giống handleFormattedAmountChange bên iBoard).
String formatMoney(int value) =>
    value.toString().replaceAllMapped(_thousands, (_) => ',');

/// "1,500,000" -> 1500000, rỗng -> null.
int? parseMoney(String text) {
  final digits = text.replaceAll(_nonDigit, '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

String formatHms(DateTime t) =>
    '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

String formatDateTime(DateTime t) =>
    '${_two(t.day)}/${_two(t.month)}/${t.year} ${formatHms(t)}';

String formatHm(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

String _two(int v) => v.toString().padLeft(2, '0');

/// Chỉ cho nhập số, tự chèn dấu phẩy phân cách hàng nghìn.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter({this.maxDigits = 15});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return TextEditingValue.empty;
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.length > maxDigits) return oldValue;
    final formatted = formatMoney(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Đổi tiền, định dạng và đọc số tiền. Chỉ dùng số nguyên, không dùng double.
library;

/// Đổi [amountMinor] từ loại tiền [from] sang [to].
///
/// [usdVndRate] là số đồng cho 1 USD, do người dùng nhập. Trả về null khi cần
/// tỷ giá mà chưa có. Làm tròn đến đơn vị nhỏ nhất gần nhất.
int? convertMinor(int amountMinor, String from, String to,
    {int? usdVndRate}) {
  if (from == to || amountMinor == 0) return amountMinor;
  if (usdVndRate == null || usdVndRate <= 0) return null;
  if (from == 'USD' && to == 'VND') {
    return _roundDiv(amountMinor * usdVndRate, 100);
  }
  if (from == 'VND' && to == 'USD') {
    return _roundDiv(amountMinor * 100, usdVndRate);
  }
  throw ArgumentError('Chưa hỗ trợ đổi $from sang $to');
}

int _roundDiv(int a, int b) =>
    a >= 0 ? (a + b ~/ 2) ~/ b : -((-a + b ~/ 2) ~/ b);

/// 1234567 VND → "1.234.567 ₫"; 123456 USD (cent) → "$1,234.56".
String formatMinor(int minor, String currency, {bool showPlus = false}) {
  final abs = minor.abs();
  final String body;
  if (currency == 'USD') {
    final cents = (abs % 100).toString().padLeft(2, '0');
    body = '\$${_group(abs ~/ 100, ',')}.$cents';
  } else {
    body = '${_group(abs, '.')} ₫';
  }
  if (minor < 0) return '−$body';
  if (showPlus && minor > 0) return '+$body';
  return body;
}

String _group(int value, String separator) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Đọc số tiền người dùng gõ. VND: "55000" hoặc "55.000". USD: "12.5" hoặc
/// "1,234.56". Trả về null nếu không hợp lệ.
int? parseMinor(String input, String currency) {
  final text = input.trim().replaceAll(' ', '');
  if (text.isEmpty) return null;
  if (currency == 'USD') {
    final match =
        RegExp(r'^(\d{1,13})(?:\.(\d{1,2}))?$').firstMatch(text.replaceAll(',', ''));
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final cents = int.parse((match.group(2) ?? '').padRight(2, '0'));
    return whole * 100 + cents;
  }
  final digits = text.replaceAll('.', '').replaceAll(',', '');
  if (!RegExp(r'^\d{1,15}$').hasMatch(digits)) return null;
  return int.parse(digits);
}

/// Ngày dạng "YYYY-MM-DD", theo ngày trên lịch của máy.
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

const List<String> _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

/// "Hôm nay, 12/11", "Hôm qua, 11/11", "Thứ Ba, 10/11".
String dayLabel(String key, DateTime today) {
  final parts = key.split('-').map(int.parse).toList();
  final date = DateTime(parts[0], parts[1], parts[2]);
  final short =
      '${parts[2].toString().padLeft(2, '0')}/${parts[1].toString().padLeft(2, '0')}';
  final todayKey = dateKey(today);
  final yesterdayKey =
      dateKey(DateTime(today.year, today.month, today.day - 1));
  if (key == todayKey) return 'Hôm nay, $short';
  if (key == yesterdayKey) return 'Hôm qua, $short';
  return '${_weekdays[date.weekday - 1]}, $short';
}

String monthLabel(int year, int month) => 'Tháng $month, $year';

/// "2027-06-30" → "30/06/2027".
String shortDate(String key) {
  final parts = key.split('-');
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// Số tiền để điền sẵn vào ô nhập, có dấu ngăn cách hàng nghìn:
/// 1234567 VND → "1.234.567"; 123450 USD (cent) → "1,234.50"; 100000 → "1,000".
String amountText(int minor, String currency) {
  final abs = minor.abs();
  if (currency == 'USD') {
    final cents = abs % 100;
    final whole = _group(abs ~/ 100, ',');
    return cents == 0 ? whole : '$whole.${cents.toString().padLeft(2, '0')}';
  }
  return _group(abs, '.');
}

/// Định dạng lại chữ người dùng đang gõ trong ô số tiền.
///
/// VND: chỉ giữ chữ số, tối đa 15 chữ số, thêm dấu chấm mỗi 3 số
/// ("1000000" → "1.000.000"). USD: dấu chấm là phần lẻ (tối đa 2 số), dấu
/// phẩy ngăn hàng nghìn ("1234.5" → "1,234.5"). Chuỗi rỗng giữ nguyên rỗng.
String groupAmountInput(String raw, String currency) {
  if (currency == 'USD') {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    final dot = cleaned.indexOf('.');
    var whole = dot < 0 ? cleaned : cleaned.substring(0, dot);
    var fraction =
        dot < 0 ? '' : cleaned.substring(dot + 1).replaceAll('.', '');
    if (whole.length > 13) whole = whole.substring(0, 13);
    if (fraction.length > 2) fraction = fraction.substring(0, 2);
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.isEmpty && dot >= 0) whole = '0';
    final grouped = whole.isEmpty ? '' : _group(int.parse(whole), ',');
    return dot < 0 ? grouped : '$grouped.$fraction';
  }
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 15) digits = digits.substring(0, 15);
  if (digits.isEmpty) return '';
  return _group(int.parse(digits), '.');
}

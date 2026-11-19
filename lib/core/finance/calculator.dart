/// Máy tính trong ô số tiền: cộng, trừ, nhân, chia trên số nguyên đơn vị nhỏ
/// nhất (đồng, hoặc cent với USD). Không dùng double nên không lệch số lẻ.
library;

import 'finance_core.dart' show maxAmountMinor;
import 'money.dart';

enum CalcOp { add, subtract, multiply, divide }

extension CalcOpSymbol on CalcOp {
  String get symbol => switch (this) {
        CalcOp.add => '+',
        CalcOp.subtract => '−',
        CalcOp.multiply => '×',
        CalcOp.divide => '÷',
      };
}

/// Kết quả tính: [value] khi tính được, [error] khi không
/// ('divide_by_zero' hoặc 'too_large').
class CalcResult {
  const CalcResult.ok(int this.value) : error = null;
  const CalcResult.fail(String this.error) : value = null;

  final int? value;
  final String? error;
}

/// Giới hạn cho số trung gian khi tính, để phép nhân không tràn số.
const int _cap = 1000000000000000;

class AmountCalculator {
  AmountCalculator(this.currency);

  /// 'VND' hoặc 'USD'. Đổi được khi người dùng chọn ví khác loại tiền.
  String currency;

  /// Chữ người dùng gõ cho từng số: chỉ chữ số, USD có thể có một dấu '.'.
  final List<String> _numbers = [''];
  final List<CalcOp> _ops = [];

  bool get _usd => currency == 'USD';
  int get _scale => _usd ? 100 : 1;

  /// Chưa gõ gì.
  bool get isEmpty => _ops.isEmpty && _numbers.single.isEmpty;

  /// Có phép tính chưa ra kết quả, ví dụ "120.000 − 40.000".
  bool get hasPendingOperation => _ops.isNotEmpty;

  /// Chữ của số đang gõ (số cuối cùng), chưa có dấu ngăn cách.
  String get currentText => _numbers.last;

  /// Gõ một chữ số, hoặc '000'.
  void digit(String digits) {
    for (final d in digits.split('')) {
      _appendDigit(d);
    }
  }

  void _appendDigit(String d) {
    var text = _numbers.last;
    final dot = text.indexOf('.');
    if (dot >= 0) {
      if (text.length - dot - 1 >= 2) return;
    } else {
      if (text == '0') text = '';
      if (text.isEmpty && d == '0') {
        _numbers[_numbers.length - 1] = '0';
        return;
      }
      if (text.length >= (_usd ? 12 : 14)) return;
    }
    _numbers[_numbers.length - 1] = text + d;
  }

  /// Dấu thập phân, chỉ dùng cho USD.
  void decimal() {
    if (!_usd) return;
    final text = _numbers.last;
    if (text.contains('.')) return;
    _numbers[_numbers.length - 1] = text.isEmpty ? '0.' : '$text.';
  }

  /// Bấm một phép tính. Bấm hai phép liền nhau thì phép sau thay phép trước.
  void operator(CalcOp op) {
    if (_numbers.last.isEmpty) {
      if (_ops.isNotEmpty) _ops[_ops.length - 1] = op;
      return;
    }
    _ops.add(op);
    _numbers.add('');
  }

  /// Xóa một ký tự; nếu số đang gõ trống thì xóa phép tính trước nó.
  void backspace() {
    final text = _numbers.last;
    if (text.isNotEmpty) {
      _numbers[_numbers.length - 1] = text.substring(0, text.length - 1);
    } else if (_ops.isNotEmpty) {
      _ops.removeLast();
      _numbers.removeLast();
    }
  }

  void clear() {
    _numbers
      ..clear()
      ..add('');
    _ops.clear();
  }

  /// Điền sẵn một số tiền (khi sửa giao dịch hoặc chạm chip gợi ý).
  void setMinor(int minor) {
    clear();
    if (minor <= 0) return;
    if (_usd) {
      final cents = minor % 100;
      final whole = (minor ~/ 100).toString();
      _numbers[0] = cents == 0
          ? whole
          : '$whole.${cents.toString().padLeft(2, '0')}';
    } else {
      _numbers[0] = minor.toString();
    }
  }

  /// Thay số đang gõ bằng [minor], giữ các số và phép tính trước đó.
  void replaceCurrent(int minor) {
    final keepNumbers = List<String>.of(_numbers)..removeLast();
    final keepOps = List<CalcOp>.of(_ops);
    setMinor(minor);
    final current = _numbers.single;
    _numbers
      ..clear()
      ..addAll(keepNumbers)
      ..add(current);
    _ops
      ..clear()
      ..addAll(keepOps);
  }

  int _toMinor(String text) {
    if (text.isEmpty || text == '.') return 0;
    if (!_usd) return int.parse(text);
    final parts = text.split('.');
    final whole = parts[0].isEmpty ? 0 : int.parse(parts[0]);
    final fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
    return whole * 100 + int.parse(fraction);
  }

  /// Tính kết quả. Nhân chia trước, cộng trừ sau. Phép tính cuối chưa có số
  /// thì bỏ qua.
  CalcResult evaluate() {
    final numbers = List<String>.of(_numbers);
    final ops = List<CalcOp>.of(_ops);
    if (numbers.length > 1 && numbers.last.isEmpty) {
      numbers.removeLast();
      ops.removeLast();
    }
    // Bước 1: gộp nhân chia thành từng số hạng.
    final terms = <int>[_toMinor(numbers.first)];
    final signs = <CalcOp>[];
    for (var i = 0; i < ops.length; i++) {
      final b = _toMinor(numbers[i + 1]);
      final op = ops[i];
      if (op == CalcOp.multiply || op == CalcOp.divide) {
        final a = terms.removeLast();
        final int next;
        if (op == CalcOp.multiply) {
          if (a != 0 && b.abs() > (_cap * _scale) ~/ a.abs()) {
            return const CalcResult.fail('too_large');
          }
          next = _roundDiv(a * b, _scale);
        } else {
          if (b == 0) return const CalcResult.fail('divide_by_zero');
          next = _roundDiv(a * _scale, b);
        }
        if (next.abs() > _cap) return const CalcResult.fail('too_large');
        terms.add(next);
      } else {
        signs.add(op);
        terms.add(b);
      }
    }
    // Bước 2: cộng trừ từ trái sang phải.
    var total = terms.first;
    for (var i = 0; i < signs.length; i++) {
      total = signs[i] == CalcOp.add ? total + terms[i + 1] : total - terms[i + 1];
      if (total.abs() > _cap) return const CalcResult.fail('too_large');
    }
    if (total > maxAmountMinor) return const CalcResult.fail('too_large');
    return CalcResult.ok(total);
  }

  /// Thay cả phép tính bằng kết quả. Trả về false nếu không tính được.
  bool collapse() {
    final result = evaluate();
    final value = result.value;
    if (value == null) return false;
    if (value <= 0) {
      clear();
    } else {
      setMinor(value);
    }
    return true;
  }

  String _show(String text) =>
      text.isEmpty ? '' : groupAmountInput(text, currency);

  /// Dòng nhỏ phía trên: "120.000 − 40.000". Trống khi chưa có phép tính.
  String get expressionText {
    if (_ops.isEmpty) return '';
    final buffer = StringBuffer(_show(_numbers.first));
    for (var i = 0; i < _ops.length; i++) {
      buffer.write(' ${_ops[i].symbol} ');
      buffer.write(_show(_numbers[i + 1]));
    }
    return buffer.toString().trimRight();
  }

  /// Số lớn ở giữa: số đang gõ, hoặc kết quả tạm khi đang có phép tính.
  String get displayText {
    if (_ops.isEmpty) {
      final text = _show(_numbers.single);
      return text.isEmpty ? '0' : text;
    }
    final value = evaluate().value;
    if (value == null) return '…';
    final shown = amountText(value, currency);
    return value < 0 ? '−$shown' : shown;
  }
}

int _roundDiv(int a, int b) {
  final negative = (a < 0) != (b < 0);
  final q = (a.abs() + b.abs() ~/ 2) ~/ b.abs();
  return negative ? -q : q;
}

/// Gợi ý số tiền theo số đang gõ: gõ "35" (VND) → 35.000, 350.000,
/// 3.500.000. Số đã từ 1.000 trở lên thì không gợi ý.
List<int> amountSuggestions(String currentText, String currency) {
  if (currentText.isEmpty || currentText.contains('.')) return const [];
  final value = int.tryParse(currentText);
  if (value == null || value <= 0 || value >= 1000) return const [];
  final unit = currency == 'USD' ? 100 : 1;
  final factors = currency == 'USD' ? [10, 100, 1000] : [1000, 10000, 100000];
  return [
    for (final f in factors)
      if (value * f * unit <= maxAmountMinor) value * f * unit,
  ];
}

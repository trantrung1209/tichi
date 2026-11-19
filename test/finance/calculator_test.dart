import 'package:flutter_test/flutter_test.dart';
import 'package:tichi/core/finance/calculator.dart';

void main() {
  AmountCalculator vnd() => AmountCalculator('VND');

  test('gõ số có dấu chấm ngăn hàng nghìn, 000 thêm ba số 0', () {
    final c = vnd()
      ..digit('35')
      ..digit('000');
    expect(c.displayText, '35.000');
    expect(c.evaluate().value, 35000);
    expect(c.expressionText, '');
  });

  test('số 0 ở đầu bị bỏ, chưa gõ gì thì hiện 0', () {
    final c = vnd();
    expect(c.displayText, '0');
    c
      ..digit('000')
      ..digit('5');
    expect(c.displayText, '5');
  });

  test('nhân chia trước, cộng trừ sau', () {
    final c = vnd()
      ..digit('100000')
      ..operator(CalcOp.add)
      ..digit('20000')
      ..operator(CalcOp.multiply)
      ..digit('3');
    expect(c.expressionText, '100.000 + 20.000 × 3');
    expect(c.evaluate().value, 160000);
    expect(c.displayText, '160.000');
  });

  test('bấm hai phép liền nhau thì phép sau thay phép trước', () {
    final c = vnd()
      ..digit('120000')
      ..operator(CalcOp.add)
      ..operator(CalcOp.subtract)
      ..digit('40000');
    expect(c.expressionText, '120.000 − 40.000');
    expect(c.evaluate().value, 80000);
  });

  test('phép tính cuối chưa có số thì bỏ qua', () {
    final c = vnd()
      ..digit('50000')
      ..operator(CalcOp.divide);
    expect(c.evaluate().value, 50000);
  });

  test('chia làm tròn đến đồng', () {
    final c = vnd()
      ..digit('100000')
      ..operator(CalcOp.divide)
      ..digit('3');
    expect(c.evaluate().value, 33333);
  });

  test('chia cho 0 báo lỗi', () {
    final c = vnd()
      ..digit('100')
      ..operator(CalcOp.divide)
      ..digit('0');
    expect(c.evaluate().error, 'divide_by_zero');
    expect(c.displayText, '…');
  });

  test('kết quả âm vẫn tính được để màn hình báo lỗi', () {
    final c = vnd()
      ..digit('10')
      ..operator(CalcOp.subtract)
      ..digit('50');
    expect(c.evaluate().value, -40);
    expect(c.displayText, '−40');
  });

  test('số quá lớn báo lỗi, không tràn số', () {
    final c = vnd()
      ..digit('99999999999999')
      ..operator(CalcOp.multiply)
      ..digit('99999999999999');
    expect(c.evaluate().error, 'too_large');
  });

  test('xóa lùi: xóa chữ số, rồi xóa phép tính', () {
    final c = vnd()
      ..digit('12')
      ..operator(CalcOp.add)
      ..digit('3');
    c.backspace();
    expect(c.expressionText, '12 +');
    c.backspace();
    expect(c.hasPendingOperation, isFalse);
    expect(c.displayText, '12');
  });

  test('= gộp phép tính thành kết quả', () {
    final c = vnd()
      ..digit('120000')
      ..operator(CalcOp.subtract)
      ..digit('40000');
    expect(c.collapse(), isTrue);
    expect(c.hasPendingOperation, isFalse);
    expect(c.displayText, '80.000');
  });

  test('USD: dấu thập phân và nhân theo đô la', () {
    final c = AmountCalculator('USD')
      ..digit('12')
      ..decimal()
      ..digit('505');
    expect(c.displayText, '12.50');
    c
      ..operator(CalcOp.multiply)
      ..digit('3');
    expect(c.evaluate().value, 3750);
  });

  test('điền sẵn số tiền khi sửa giao dịch', () {
    final c = vnd()..setMinor(750000);
    expect(c.displayText, '750.000');
    final usd = AmountCalculator('USD')..setMinor(1234);
    expect(usd.displayText, '12.34');
  });

  test('gợi ý số tiền theo số đang gõ', () {
    expect(amountSuggestions('35', 'VND'), [35000, 350000, 3500000]);
    expect(amountSuggestions('1500', 'VND'), isEmpty);
    expect(amountSuggestions('', 'VND'), isEmpty);
    expect(amountSuggestions('5', 'USD'), [5000, 50000, 500000]);
  });
}

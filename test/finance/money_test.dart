import 'package:flutter_test/flutter_test.dart';
import 'package:tichi/core/finance/finance_core.dart';
import 'package:tichi/core/finance/money.dart';

void main() {
  group('Đổi tiền', () {
    test('cùng loại tiền thì giữ nguyên', () {
      expect(convertMinor(55000, 'VND', 'VND'), 55000);
    });

    test('USD sang VND theo tỷ giá nhập tay', () {
      // 100,00 USD × 26.300 = 2.630.000 đồng
      expect(convertMinor(10000, 'USD', 'VND', usdVndRate: 26300), 2630000);
      // 0,01 USD × 26.300 = 263 đồng
      expect(convertMinor(1, 'USD', 'VND', usdVndRate: 26300), 263);
    });

    test('VND sang USD làm tròn đến cent gần nhất', () {
      // 2.630.000 / 26.300 = 100,00 USD
      expect(convertMinor(2630000, 'VND', 'USD', usdVndRate: 26300), 10000);
      // 100.000 / 26.300 = 3,8023 USD, làm tròn 3,80
      expect(convertMinor(100000, 'VND', 'USD', usdVndRate: 26300), 380);
      expect(convertMinor(-100000, 'VND', 'USD', usdVndRate: 26300), -380);
    });

    test('chưa có tỷ giá thì trả về null, trừ số 0', () {
      expect(convertMinor(10000, 'USD', 'VND'), isNull);
      expect(convertMinor(0, 'USD', 'VND'), 0);
    });
  });

  group('Định dạng số tiền', () {
    test('VND', () {
      expect(formatMinor(0, 'VND'), '0 ₫');
      expect(formatMinor(55000, 'VND'), '55.000 ₫');
      expect(formatMinor(27400000, 'VND'), '27.400.000 ₫');
      expect(formatMinor(-9640000, 'VND'), '−9.640.000 ₫');
      expect(formatMinor(18000000, 'VND', showPlus: true), '+18.000.000 ₫');
    });

    test('USD', () {
      expect(formatMinor(5, 'USD'), '\$0.05');
      expect(formatMinor(123456, 'USD'), '\$1,234.56');
      expect(formatMinor(-1000, 'USD'), '−\$10.00');
    });
  });

  group('Đọc số tiền người dùng gõ', () {
    test('VND', () {
      expect(parseMinor('55000', 'VND'), 55000);
      expect(parseMinor('55.000', 'VND'), 55000);
      expect(parseMinor(' 1 000 000 ', 'VND'), 1000000);
      expect(parseMinor('', 'VND'), isNull);
      expect(parseMinor('12a', 'VND'), isNull);
      expect(parseMinor('-5', 'VND'), isNull);
      expect(parseMinor('9999999999999999', 'VND'), isNull);
    });

    test('USD', () {
      expect(parseMinor('12', 'USD'), 1200);
      expect(parseMinor('12.5', 'USD'), 1250);
      expect(parseMinor('1,234.56', 'USD'), 123456);
      expect(parseMinor('1.234', 'USD'), isNull);
    });
  });

  group('Nhãn ngày', () {
    final today = DateTime(2026, 11, 12);

    test('hôm nay, hôm qua, thứ trong tuần', () {
      expect(dateKey(today), '2026-11-12');
      expect(dayLabel('2026-11-12', today), 'Hôm nay, 12/11');
      expect(dayLabel('2026-11-11', today), 'Hôm qua, 11/11');
      expect(dayLabel('2026-11-10', today), 'Thứ Ba, 10/11');
      expect(dayLabel('2026-11-08', today), 'Chủ nhật, 08/11');
    });

    test('hôm qua của ngày đầu tháng', () {
      expect(dayLabel('2026-10-31', DateTime(2026, 11, 1)), 'Hôm qua, 31/10');
    });
  });

  group('Truy vấn cho giao diện', () {
    late FinanceCore core;
    setUp(() => core = FinanceCore.inMemory());
    tearDown(() => core.close());

    test('danh sách giao dịch theo tháng, mới nhất trước, có tên ví và '
        'danh mục', () {
      final bank = core.createWallet(
          name: 'Ngân hàng',
          type: 'BANK',
          currencyCode: 'VND',
          openingBalanceMinor: 1000000);
      final cash =
          core.createWallet(name: 'Tiền mặt', type: 'CASH', currencyCode: 'VND');
      final food = core.createCategory(name: 'Ăn uống', type: 'EXPENSE');
      core.addExpense(
          requestId: 'a',
          walletId: bank,
          amountMinor: 55000,
          date: '2026-11-12',
          categoryId: food);
      core.transfer(
          requestId: 'b',
          fromWalletId: bank,
          toWalletId: cash,
          amountMinor: 100000,
          date: '2026-11-11');
      core.addExpense(
          requestId: 'c',
          walletId: bank,
          amountMinor: 1000,
          date: '2026-10-31');

      final november = core.transactions(monthPrefix: '2026-11');
      expect(november.map((t) => t.date), ['2026-11-12', '2026-11-11']);
      expect(november.first.categoryName, 'Ăn uống');
      expect(november.first.sourceWalletName, 'Ngân hàng');
      expect(november.first.currency, 'VND');
      expect(november[1].type, 'TRANSFER');
      expect(november[1].destinationWalletName, 'Tiền mặt');
      expect(core.transactions(limit: 1).length, 1);
      expect(core.transactions().length, 3);
    });

    test('danh sách ví có số dư, ẩn ví đã lưu trữ', () {
      core.createWallet(
          name: 'Ngân hàng',
          type: 'BANK',
          currencyCode: 'VND',
          openingBalanceMinor: 5000);
      final wallets = core.wallets();
      expect(wallets.single.name, 'Ngân hàng');
      expect(wallets.single.balanceMinor, 5000);
    });

    test('lưu và đọc cài đặt', () {
      expect(core.getSetting('rate_usd_vnd'), isNull);
      core.setSetting('rate_usd_vnd', '26300');
      core.setSetting('rate_usd_vnd', '26400');
      expect(core.getSetting('rate_usd_vnd'), '26400');
    });
  });

  group('ô nhập số tiền tự thêm dấu', () {
    test('VND thêm dấu chấm mỗi 3 số, bỏ số 0 đầu và chữ lạ', () {
      expect(groupAmountInput('', 'VND'), '');
      expect(groupAmountInput('1000', 'VND'), '1.000');
      expect(groupAmountInput('1.0000', 'VND'), '10.000');
      expect(groupAmountInput('0012345678', 'VND'), '12.345.678');
      expect(groupAmountInput('12a3', 'VND'), '123');
      expect(groupAmountInput('1234567890123456789', 'VND'),
          '12.345.678.901.234');
    });

    test('USD dùng dấu phẩy hàng nghìn, tối đa 2 số lẻ', () {
      expect(groupAmountInput('1234', 'USD'), '1,234');
      expect(groupAmountInput('1,2345.678', 'USD'), '12,345.67');
      expect(groupAmountInput('.5', 'USD'), '0.5');
      expect(groupAmountInput('12.', 'USD'), '12.');
      expect(groupAmountInput('1.2.3', 'USD'), '1.23');
    });

    test('số điền sẵn có dấu và đọc lại ra đúng số', () {
      expect(amountText(27400000, 'VND'), '27.400.000');
      expect(amountText(123450, 'USD'), '1,234.50');
      expect(amountText(100000, 'USD'), '1,000');
      for (final (minor, currency) in [
        (27400000, 'VND'),
        (123450, 'USD'),
        (100000, 'USD'),
        (5, 'USD'),
      ]) {
        expect(parseMinor(amountText(minor, currency), currency), minor);
      }
    });
  });
}

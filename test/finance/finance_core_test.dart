import 'package:flutter_test/flutter_test.dart';
import 'package:tichi/core/finance/finance_core.dart';

/// Kiểm tra một lỗi nghiệp vụ theo mã lỗi.
Matcher throwsFinance(String code) => throwsA(
    isA<FinanceException>().having((e) => e.code, 'code', code));

void main() {
  late FinanceCore core;
  late String cash;
  late String bank;
  late String usd;
  late String savings;
  var requestCounter = 0;
  String nextRequest() => 'req-${requestCounter++}';

  setUp(() {
    core = FinanceCore.inMemory();
    cash = core.createWallet(
        name: 'Tiền mặt', type: 'CASH', currencyCode: 'VND');
    bank = core.createWallet(
        name: 'Ngân hàng',
        type: 'BANK',
        currencyCode: 'VND',
        openingBalanceMinor: 20000000);
    usd = core.createWallet(
        name: 'USD', type: 'BANK', currencyCode: 'USD');
    savings = core.createWallet(
        name: 'Ví tiết kiệm', type: 'SAVINGS', currencyCode: 'VND');
  });

  tearDown(() => core.close());

  group('Số dư ví', () {
    test('bằng số dư đầu khi chưa có giao dịch', () {
      expect(core.walletBalance(bank), 20000000);
      expect(core.walletBalance(cash), 0);
    });

    test('thu làm tăng, chi làm giảm', () {
      core.addIncome(
          requestId: nextRequest(),
          walletId: cash,
          amountMinor: 500000,
          date: '2026-11-12');
      core.addExpense(
          requestId: nextRequest(),
          walletId: cash,
          amountMinor: 55000,
          date: '2026-11-12');
      expect(core.walletBalance(cash), 445000);
    });

    test('từ chối số tiền bằng 0 hoặc âm', () {
      expect(
          () => core.addIncome(
              requestId: nextRequest(),
              walletId: cash,
              amountMinor: 0,
              date: '2026-11-12'),
          throwsFinance('invalid_amount'));
      expect(
          () => core.addExpense(
              requestId: nextRequest(),
              walletId: bank,
              amountMinor: -1,
              date: '2026-11-12'),
          throwsFinance('invalid_amount'));
    });

    test('từ chối loại tiền chưa hỗ trợ', () {
      expect(
          () => core.createWallet(
              name: 'Euro', type: 'BANK', currencyCode: 'EUR'),
          throwsFinance('unsupported_currency'));
    });
  });

  group('Ví thường được phép âm', () {
    test('chi vượt số dư thì ví âm', () {
      core.addExpense(
          requestId: nextRequest(),
          walletId: cash,
          amountMinor: 100000,
          date: '2026-11-12');
      expect(core.walletBalance(cash), -100000);
      expect(core.totalAssetsByCurrency()['VND'], 19900000);
    });

    test('chuyển vượt số dư thì ví nguồn âm', () {
      core.transfer(
          requestId: nextRequest(),
          fromWalletId: bank,
          toWalletId: cash,
          amountMinor: 20000001,
          date: '2026-11-12');
      expect(core.walletBalance(bank), -1);
      expect(core.walletBalance(cash), 20000001);
    });

    test('khi yêu cầu đủ tiền thì chuyển vượt số dư bị chặn (kiểm thử 2)', () {
      expect(
          () => core.transfer(
              requestId: nextRequest(),
              fromWalletId: bank,
              toWalletId: cash,
              amountMinor: 20000001,
              date: '2026-11-12',
              requireSufficientFunds: true),
          throwsA(isA<InsufficientFundsException>()
              .having((e) => e.shortfallMinor, 'shortfall', 1)
              .having((e) => e.currency, 'currency', 'VND')));
      expect(core.walletBalance(bank), 20000000);
      expect(core.activeTransactionCount(), 0);
    });
  });

  group('Sửa và lưu trữ ví, danh mục', () {
    test('ví mới có biểu tượng và màu mặc định theo loại', () {
      final info = core.wallet(bank);
      expect(info.icon, 'bank');
      expect(info.color, 'blue');
      expect(core.wallet(savings).icon, 'coins');
    });

    test('nhiều ví ngân hàng, đổi tên và biểu tượng', () {
      final second = core.createWallet(
          name: 'Techcombank', type: 'BANK', currencyCode: 'VND');
      core.updateWallet(second, name: 'TCB', icon: 'card', color: 'red');
      final info = core.wallet(second);
      expect(info.name, 'TCB');
      expect(info.icon, 'card');
      expect(info.color, 'red');
      expect(core.wallets().where((w) => w.type == 'BANK').length, 3);
    });

    test('ví lưu trữ bị ẩn, không nhận giao dịch mới, vẫn tính tài sản', () {
      core.setWalletArchived(bank, true);
      expect(core.wallets().any((w) => w.id == bank), isFalse);
      expect(core.totalAssetsByCurrency()['VND'], 20000000);
      expect(
          () => core.addExpense(
              requestId: nextRequest(),
              walletId: bank,
              amountMinor: 1000,
              date: '2026-11-12'),
          throwsFinance('wallet_archived'));
      core.setWalletArchived(bank, false);
      expect(core.wallets().any((w) => w.id == bank), isTrue);
    });

    test('tên trống bị từ chối', () {
      expect(
          () => core.createWallet(name: '  ', type: 'CASH', currencyCode: 'VND'),
          throwsFinance('invalid_name'));
    });

    test('danh mục: tạo, sửa, ẩn mà giao dịch cũ vẫn giữ tên', () {
      final coffee = core.createCategory(
          name: 'Cà phê', type: 'EXPENSE', icon: 'coffee', color: 'orange');
      core.addExpense(
          requestId: nextRequest(),
          walletId: bank,
          amountMinor: 35000,
          date: '2026-11-12',
          categoryId: coffee);
      core.updateCategory(coffee, name: 'Cà phê sáng');
      core.setCategoryArchived(coffee, true);
      expect(core.categories('EXPENSE').any((c) => c.id == coffee), isFalse);
      expect(
          core
              .categories('EXPENSE', includeArchived: true)
              .firstWhere((c) => c.id == coffee)
              .isArchived,
          isTrue);
      final tx = core.transactions().single;
      expect(tx.categoryName, 'Cà phê sáng');
      expect(tx.categoryIcon, 'coffee');
    });
  });

  group('Chuyển ví', () {
    test('cùng loại tiền: ví nguồn giảm, ví nhận tăng, tổng tài sản giữ nguyên '
        '(kiểm thử 14)', () {
      final before = core.totalAssetsByCurrency()['VND'];
      core.transfer(
          requestId: nextRequest(),
          fromWalletId: bank,
          toWalletId: cash,
          amountMinor: 5000000,
          date: '2026-11-12');
      expect(core.walletBalance(bank), 15000000);
      expect(core.walletBalance(cash), 5000000);
      expect(core.totalAssetsByCurrency()['VND'], before);
    });

    test('qua lại giữa hai ví trở về số dư ban đầu (kiểm thử 8)', () {
      core.transfer(
          requestId: nextRequest(),
          fromWalletId: bank,
          toWalletId: cash,
          amountMinor: 3000000,
          date: '2026-11-12');
      core.transfer(
          requestId: nextRequest(),
          fromWalletId: cash,
          toWalletId: bank,
          amountMinor: 3000000,
          date: '2026-11-12');
      expect(core.walletBalance(bank), 20000000);
      expect(core.walletBalance(cash), 0);
    });

    test('không tính là thu hay chi trong báo cáo tháng (kiểm thử 13)', () {
      core.transfer(
          requestId: nextRequest(),
          fromWalletId: bank,
          toWalletId: cash,
          amountMinor: 5000000,
          date: '2026-11-12');
      final summary =
          core.monthSummary(year: 2026, month: 11, currencyCode: 'VND');
      expect(summary.incomeMinor, 0);
      expect(summary.expenseMinor, 0);
    });

    test('từ chối chuyển vào chính ví đó', () {
      expect(
          () => core.transfer(
              requestId: nextRequest(),
              fromWalletId: bank,
              toWalletId: bank,
              amountMinor: 1000,
              date: '2026-11-12'),
          throwsFinance('same_wallet'));
    });

    test('khác loại tiền: bắt buộc nhập số tiền ví nhận được', () {
      expect(
          () => core.transfer(
              requestId: nextRequest(),
              fromWalletId: bank,
              toWalletId: usd,
              amountMinor: 2600000,
              date: '2026-11-12'),
          throwsFinance('destination_amount_required'));
    });

    test('khác loại tiền: mỗi ví thay đổi theo loại tiền của mình', () {
      // 2.600.000 đồng đổi được 100,00 USD (10000 cent).
      core.transfer(
          requestId: nextRequest(),
          fromWalletId: bank,
          toWalletId: usd,
          amountMinor: 2600000,
          destinationAmountMinor: 10000,
          date: '2026-11-12');
      expect(core.walletBalance(bank), 17400000);
      expect(core.walletBalance(usd), 10000);
      expect(core.totalAssetsByCurrency(), {'VND': 17400000, 'USD': 10000});
    });

    test('cùng loại tiền: số nhận khác số chuyển bị từ chối', () {
      expect(
          () => core.transfer(
              requestId: nextRequest(),
              fromWalletId: bank,
              toWalletId: cash,
              amountMinor: 1000,
              destinationAmountMinor: 999,
              date: '2026-11-12'),
          throwsFinance('amount_mismatch'));
    });
  });

  group('Chống trùng (kiểm thử 9)', () {
    test('bấm Lưu nhiều lần với cùng mã yêu cầu chỉ tạo một giao dịch', () {
      final first = core.transfer(
          requestId: 'same-request',
          fromWalletId: bank,
          toWalletId: cash,
          amountMinor: 200000,
          date: '2026-11-12');
      final second = core.transfer(
          requestId: 'same-request',
          fromWalletId: bank,
          toWalletId: cash,
          amountMinor: 200000,
          date: '2026-11-12');
      expect(second, first);
      expect(core.activeTransactionCount(), 1);
      expect(core.walletBalance(bank), 19800000);
      expect(core.walletBalance(cash), 200000);
    });
  });

  group('Hoàn tác khi lỗi (kiểm thử 10 và 11)', () {
    test('lỗi sau khi ghi và trước khi commit thì không còn dấu vết', () {
      final failing = FinanceCore.inMemory(
          debugHook: (step) => throw StateError('giả lập lỗi tại $step'));
      final a = failing.createWallet(
          name: 'A',
          type: 'BANK',
          currencyCode: 'VND',
          openingBalanceMinor: 1000000);
      final b =
          failing.createWallet(name: 'B', type: 'CASH', currencyCode: 'VND');
      expect(
          () => failing.transfer(
              requestId: 'r1',
              fromWalletId: a,
              toWalletId: b,
              amountMinor: 400000,
              date: '2026-11-12'),
          throwsStateError);
      expect(failing.walletBalance(a), 1000000);
      expect(failing.walletBalance(b), 0);
      expect(failing.activeTransactionCount(), 0);
      failing.close();
    });
  });

  group('Xóa và khôi phục giao dịch (kiểm thử 12)', () {
    test('xóa khoản chi trả tiền về ví, khôi phục thì trừ lại', () {
      final id = core.addExpense(
          requestId: nextRequest(),
          walletId: bank,
          amountMinor: 680000,
          date: '2026-11-11');
      expect(core.walletBalance(bank), 19320000);
      core.deleteTransaction(id);
      expect(core.walletBalance(bank), 20000000);
      core.restoreTransaction(id);
      expect(core.walletBalance(bank), 19320000);
    });

    test('xóa lần chuyển ví trả cả hai ví về như cũ', () {
      final id = core.transfer(
          requestId: nextRequest(),
          fromWalletId: bank,
          toWalletId: cash,
          amountMinor: 500000,
          date: '2026-11-11');
      core.deleteTransaction(id);
      expect(core.walletBalance(bank), 20000000);
      expect(core.walletBalance(cash), 0);
    });

    test('xóa khoản thu đã được chi thì ví thường thành âm', () {
      final income = core.addIncome(
          requestId: nextRequest(),
          walletId: cash,
          amountMinor: 100000,
          date: '2026-11-10');
      core.addExpense(
          requestId: nextRequest(),
          walletId: cash,
          amountMinor: 80000,
          date: '2026-11-11');
      core.deleteTransaction(income);
      expect(core.walletBalance(cash), -80000);
    });

    test('giao dịch đã xóa không còn trong báo cáo tháng', () {
      final id = core.addExpense(
          requestId: nextRequest(),
          walletId: bank,
          amountMinor: 420000,
          date: '2026-11-11');
      core.deleteTransaction(id);
      final summary =
          core.monthSummary(year: 2026, month: 11, currencyCode: 'VND');
      expect(summary.expenseMinor, 0);
    });
  });

  group('Báo cáo tháng', () {
    test('tách theo loại tiền và theo tháng', () {
      core.addIncome(
          requestId: nextRequest(),
          walletId: bank,
          amountMinor: 18000000,
          date: '2026-11-10');
      core.addIncome(
          requestId: nextRequest(),
          walletId: usd,
          amountMinor: 50000,
          date: '2026-11-10');
      core.addExpense(
          requestId: nextRequest(),
          walletId: bank,
          amountMinor: 680000,
          date: '2026-11-11');
      core.addExpense(
          requestId: nextRequest(),
          walletId: bank,
          amountMinor: 100000,
          date: '2026-10-31');
      final vnd = core.monthSummary(year: 2026, month: 11, currencyCode: 'VND');
      expect(vnd.incomeMinor, 18000000);
      expect(vnd.expenseMinor, 680000);
      expect(vnd.netMinor, 17320000);
      final dollars =
          core.monthSummary(year: 2026, month: 11, currencyCode: 'USD');
      expect(dollars.incomeMinor, 50000);
      expect(dollars.expenseMinor, 0);
    });
  });

  group('Ví tiết kiệm được bảo vệ (kiểm thử 17)', () {
    test('không ghi thu, chi trực tiếp vào ví tiết kiệm', () {
      expect(
          () => core.addIncome(
              requestId: nextRequest(),
              walletId: savings,
              amountMinor: 1000,
              date: '2026-11-12'),
          throwsFinance('income_into_savings'));
      expect(
          () => core.addExpense(
              requestId: nextRequest(),
              walletId: savings,
              amountMinor: 1000,
              date: '2026-11-12'),
          throwsFinance('expense_from_savings'));
    });

    test('chuyển ví thông thường không chạm được vào ví tiết kiệm', () {
      expect(
          () => core.transfer(
              requestId: nextRequest(),
              fromWalletId: bank,
              toWalletId: savings,
              amountMinor: 1000,
              date: '2026-11-12'),
          throwsFinance('transfer_into_savings'));
    });

    test('lớp tiết kiệm được phép chuyển vào và rút ra', () {
      core.transfer(
          requestId: nextRequest(),
          fromWalletId: bank,
          toWalletId: savings,
          amountMinor: 200000,
          date: '2026-11-12',
          allowSavingsDestination: true);
      expect(core.walletBalance(savings), 200000);
      expect(
          () => core.transfer(
              requestId: nextRequest(),
              fromWalletId: savings,
              toWalletId: bank,
              amountMinor: 50000,
              date: '2026-11-12'),
          throwsFinance('transfer_from_savings'));
      core.transfer(
          requestId: nextRequest(),
          fromWalletId: savings,
          toWalletId: bank,
          amountMinor: 50000,
          date: '2026-11-12',
          allowSavingsSource: true);
      expect(core.walletBalance(savings), 150000);
      expect(core.walletBalance(bank), 19850000);
    });
  });
}

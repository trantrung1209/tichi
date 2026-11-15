import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tichi/core/finance/finance_core.dart';
import 'package:tichi/core/savings/savings_center.dart';

Matcher throwsFinance(String code) => throwsA(
    isA<FinanceException>().having((e) => e.code, 'code', code));

const today = '2026-11-12';

void main() {
  late FinanceCore core;
  late SavingsCenter savings;
  late String bank;
  late String cash;
  late String usd;
  late String vault;
  late String japan;
  late String phone;
  var counter = 0;
  String req() => 'req-${counter++}';

  setUp(() {
    core = FinanceCore.inMemory();
    savings = SavingsCenter(core);
    bank = core.createWallet(
        name: 'Ngân hàng',
        type: 'BANK',
        currencyCode: 'VND',
        openingBalanceMinor: 20000000);
    cash = core.createWallet(
        name: 'Tiền mặt', type: 'CASH', currencyCode: 'VND');
    usd = core.createWallet(
        name: 'USD',
        type: 'BANK',
        currencyCode: 'USD',
        openingBalanceMinor: 50000);
    vault = core.createWallet(
        name: 'Ví tiết kiệm', type: 'SAVINGS', currencyCode: 'VND');
    japan = savings.createGoal(
        name: 'Du lịch Nhật Bản',
        targetMinor: 30000000,
        savingsWalletId: vault,
        startDate: today,
        targetDate: '2027-06-30');
    phone = savings.createGoal(
        name: 'Điện thoại mới',
        targetMinor: 15000000,
        savingsWalletId: vault,
        startDate: today,
        targetDate: '2027-09-30');
  });

  tearDown(() => core.close());

  group('Tạo mục tiêu', () {
    test('phải gắn với ví tiết kiệm', () {
      expect(
          () => savings.createGoal(
              name: 'Sai ví',
              targetMinor: 1000,
              savingsWalletId: bank,
              startDate: today,
              targetDate: '2027-01-01'),
          throwsFinance('not_savings_wallet'));
    });

    test('ngày hoàn thành không được trước ngày bắt đầu', () {
      expect(
          () => savings.createGoal(
              name: 'Sai ngày',
              targetMinor: 1000,
              savingsWalletId: vault,
              startDate: today,
              targetDate: '2026-11-01'),
          throwsFinance('invalid_dates'));
    });

    test('từ chối ngày không tồn tại', () {
      expect(
          () => savings.createGoal(
              name: 'Ngày lạ',
              targetMinor: 1000,
              savingsWalletId: vault,
              startDate: today,
              targetDate: '2027-02-30'),
          throwsFinance('invalid_date'));
    });
  });

  group('Tiết kiệm ngay', () {
    test('chuyển tiền thật, tiến độ tăng, tổng tài sản giữ nguyên '
        '(kiểm thử 1 và 14)', () {
      final before = core.totalAssetsByCurrency()['VND'];
      savings.contribute(
          requestId: req(),
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 200000,
          date: today);
      expect(core.walletBalance(bank), 19800000);
      expect(core.walletBalance(vault), 200000);
      expect(savings.savedMinor(japan), 200000);
      expect(core.totalAssetsByCurrency()['VND'], before);
    });

    test('ví nguồn không đủ tiền thì không có gì thay đổi (kiểm thử 2)', () {
      expect(
          () => savings.contribute(
              requestId: req(),
              goalId: japan,
              fromWalletId: cash,
              amountMinor: 100000,
              date: today),
          throwsA(isA<InsufficientFundsException>()
              .having((e) => e.shortfallMinor, 'shortfall', 100000)));
      expect(savings.savedMinor(japan), 0);
      expect(core.walletBalance(vault), 0);
      expect(core.activeTransactionCount(), 0);
    });

    test('bấm nút nhiều lần chỉ chuyển tiền một lần (kiểm thử 9)', () {
      final first = savings.contribute(
          requestId: 'tap',
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 200000,
          date: today);
      final second = savings.contribute(
          requestId: 'tap',
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 200000,
          date: today);
      expect(second, first);
      expect(core.activeTransactionCount(), 1);
      expect(core.walletBalance(bank), 19800000);
      expect(savings.savedMinor(japan), 200000);
    });

    test('không tính là thu hay chi trong báo cáo (kiểm thử 13)', () {
      savings.contribute(
          requestId: req(),
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 5000000,
          date: today);
      savings.withdraw(
          requestId: req(),
          goalId: japan,
          toWalletId: bank,
          amountMinor: 1000000,
          date: today);
      final summary =
          core.monthSummary(year: 2026, month: 11, currencyCode: 'VND');
      expect(summary.incomeMinor, 0);
      expect(summary.expenseMinor, 0);
    });

    test('chỉ cùng loại tiền', () {
      expect(
          () => savings.contribute(
              requestId: req(),
              goalId: japan,
              fromWalletId: usd,
              amountMinor: 1000,
              date: today),
          throwsFinance('currency_mismatch'));
    });

    test('không lấy tiền từ chính một ví tiết kiệm', () {
      final otherVault = core.createWallet(
          name: 'Ví tiết kiệm 2', type: 'SAVINGS', currencyCode: 'VND');
      expect(
          () => savings.contribute(
              requestId: req(),
              goalId: japan,
              fromWalletId: otherVault,
              amountMinor: 1000,
              date: today),
          throwsFinance('transfer_from_savings'));
    });
  });

  group('Một ví nhiều mục tiêu (kiểm thử 5)', () {
    test('mỗi mục tiêu giữ phần của mình, tổng bằng số dư ví', () {
      savings.contribute(
          requestId: req(),
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 3000000,
          date: today);
      savings.contribute(
          requestId: req(),
          goalId: phone,
          fromWalletId: bank,
          amountMinor: 1000000,
          date: today);
      expect(savings.savedMinor(japan), 3000000);
      expect(savings.savedMinor(phone), 1000000);
      expect(core.walletBalance(vault), 4000000);
      expect(savings.unallocatedMinor(vault), 0);
    });
  });

  group('Mục tiêu đạt 100% (kiểm thử 6 và 7)', () {
    test('đủ tiền thì Hoàn thành, rút bớt thì trở lại Đang thực hiện', () {
      savings.contribute(
          requestId: req(),
          goalId: phone,
          fromWalletId: bank,
          amountMinor: 15000000,
          date: today);
      expect(savings.progress(phone).status, 'COMPLETED');
      expect(savings.progress(phone).percent, 100);
      expect(savings.suggestion(phone, today), isNull);

      savings.withdraw(
          requestId: req(),
          goalId: phone,
          toWalletId: cash,
          amountMinor: 3000000,
          date: today);
      final progress = savings.progress(phone);
      expect(progress.status, 'ACTIVE');
      expect(progress.savedMinor, 12000000);
      expect(progress.percent, 80);
      expect(progress.remainingMinor, 3000000);
    });
  });

  group('Rút tiền', () {
    setUp(() {
      savings.contribute(
          requestId: req(),
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 10000000,
          date: today);
      savings.contribute(
          requestId: req(),
          goalId: phone,
          fromWalletId: bank,
          amountMinor: 2000000,
          date: today);
    });

    test('chỉ mục tiêu được chọn bị giảm (kiểm thử 3)', () {
      savings.withdraw(
          requestId: req(),
          goalId: japan,
          toWalletId: bank,
          amountMinor: 2000000,
          date: today);
      expect(savings.savedMinor(japan), 8000000);
      expect(savings.savedMinor(phone), 2000000);
      expect(core.walletBalance(vault), 10000000);
      expect(core.walletBalance(bank), 10000000);
    });

    test('không rút quá phần của mục tiêu dù ví còn đủ (kiểm thử 4 và 16)', () {
      expect(
          () => savings.withdraw(
              requestId: req(),
              goalId: phone,
              toWalletId: bank,
              amountMinor: 2000001,
              date: today),
          throwsFinance('exceeds_goal_savings'));
      expect(savings.savedMinor(phone), 2000000);
      expect(core.walletBalance(vault), 12000000);
    });

    test('không rút vào một ví tiết kiệm khác', () {
      final otherVault = core.createWallet(
          name: 'Ví tiết kiệm 2', type: 'SAVINGS', currencyCode: 'VND');
      expect(
          () => savings.withdraw(
              requestId: req(),
              goalId: japan,
              toWalletId: otherVault,
              amountMinor: 1000,
              date: today),
          throwsFinance('transfer_into_savings'));
    });

    test('không rút sang ví khác loại tiền', () {
      expect(
          () => savings.withdraw(
              requestId: req(),
              goalId: japan,
              toWalletId: usd,
              amountMinor: 1000,
              date: today),
          throwsFinance('currency_mismatch'));
    });

    test('bấm Rút nhiều lần chỉ rút một lần', () {
      savings.withdraw(
          requestId: 'withdraw-tap',
          goalId: japan,
          toWalletId: bank,
          amountMinor: 1000000,
          date: today);
      savings.withdraw(
          requestId: 'withdraw-tap',
          goalId: japan,
          toWalletId: bank,
          amountMinor: 1000000,
          date: today);
      expect(savings.savedMinor(japan), 9000000);
    });
  });

  group('Tiền có sẵn trong ví tiết kiệm', () {
    late String oldVault;
    late String emergency;

    setUp(() {
      oldVault = core.createWallet(
          name: 'Sổ tiết kiệm',
          type: 'SAVINGS',
          currencyCode: 'VND',
          openingBalanceMinor: 10000000);
      emergency = savings.createGoal(
          name: 'Quỹ dự phòng',
          targetMinor: 30000000,
          savingsWalletId: oldVault,
          startDate: today,
          targetDate: '2027-12-31');
    });

    test('ban đầu là Chưa gắn mục tiêu', () {
      expect(savings.unallocatedMinor(oldVault), 10000000);
      expect(savings.savedMinor(emergency), 0);
    });

    test('chia cho mục tiêu mà không chuyển ví', () {
      savings.allocateUnassigned(
          requestId: req(),
          goalId: emergency,
          amountMinor: 6000000,
          date: today);
      expect(savings.savedMinor(emergency), 6000000);
      expect(savings.unallocatedMinor(oldVault), 4000000);
      expect(core.walletBalance(oldVault), 10000000);
      expect(core.activeTransactionCount(), 0);
    });

    test('không chia quá phần chưa gắn', () {
      expect(
          () => savings.allocateUnassigned(
              requestId: req(),
              goalId: emergency,
              amountMinor: 10000001,
              date: today),
          throwsFinance('exceeds_unallocated'));
    });

    test('chia sẵn không tính vào chuỗi ngày', () {
      savings.allocateUnassigned(
          requestId: req(),
          goalId: emergency,
          amountMinor: 1000000,
          date: today);
      expect(savings.currentStreak(today), 0);
    });

    test('rút phần chưa gắn về ví thường', () {
      savings.allocateUnassigned(
          requestId: req(),
          goalId: emergency,
          amountMinor: 7000000,
          date: today);
      expect(
          () => savings.withdrawUnassigned(
              requestId: req(),
              savingsWalletId: oldVault,
              toWalletId: bank,
              amountMinor: 3000001,
              date: today),
          throwsFinance('exceeds_unallocated'));
      savings.withdrawUnassigned(
          requestId: req(),
          savingsWalletId: oldVault,
          toWalletId: bank,
          amountMinor: 3000000,
          date: today);
      expect(savings.unallocatedMinor(oldVault), 0);
      expect(savings.savedMinor(emergency), 7000000);
      expect(core.walletBalance(bank), 23000000);
    });
  });

  group('Xóa mục tiêu', () {
    test('tiền trở về Chưa gắn mục tiêu, ví giữ nguyên', () {
      savings.contribute(
          requestId: req(),
          goalId: phone,
          fromWalletId: bank,
          amountMinor: 2000000,
          date: today);
      savings.deleteGoal(phone);
      expect(core.walletBalance(vault), 2000000);
      expect(savings.unallocatedMinor(vault), 2000000);
      expect(() => savings.progress(phone), throwsFinance('goal_not_found'));
      savings.allocateUnassigned(
          requestId: req(),
          goalId: japan,
          amountMinor: 2000000,
          date: today);
      expect(savings.savedMinor(japan), 2000000);
    });
  });

  group('Hoàn tác khi lỗi (kiểm thử 10 và 11)', () {
    test('lỗi sau khi chuyển tiền nhưng trước khi ghi lần góp thì không còn '
        'dấu vết', () {
      final failing = FinanceCore.inMemory(debugHook: (step) {
        if (step == 'contribution_inserted') {
          throw StateError('giả lập app bị đóng');
        }
      });
      final center = SavingsCenter(failing);
      final source = failing.createWallet(
          name: 'Ngân hàng',
          type: 'BANK',
          currencyCode: 'VND',
          openingBalanceMinor: 1000000);
      final box = failing.createWallet(
          name: 'Ví tiết kiệm', type: 'SAVINGS', currencyCode: 'VND');
      final goal = center.createGoal(
          name: 'Thử',
          targetMinor: 500000,
          savingsWalletId: box,
          startDate: today,
          targetDate: '2027-01-01');
      expect(
          () => center.contribute(
              requestId: 'r1',
              goalId: goal,
              fromWalletId: source,
              amountMinor: 200000,
              date: today),
          throwsStateError);
      expect(failing.walletBalance(source), 1000000);
      expect(failing.walletBalance(box), 0);
      expect(failing.activeTransactionCount(), 0);
      expect(center.savedMinor(goal), 0);
      expect(failing.transactionIdForRequest('r1'), isNull);
      failing.close();
    });
  });

  group('Xóa hoặc đảo ngược giao dịch tiết kiệm (kiểm thử 12)', () {
    test('xóa giao dịch góp thì tiến độ giảm theo', () {
      savings.contribute(
          requestId: 'c1',
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 500000,
          date: today);
      core.deleteTransaction(core.transactionIdForRequest('c1')!);
      expect(savings.savedMinor(japan), 0);
      expect(core.walletBalance(bank), 20000000);
      expect(core.walletBalance(vault), 0);
    });

    test('xóa giao dịch góp khi tiền đã bị rút thì bị chặn', () {
      savings.contribute(
          requestId: 'c1',
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 500000,
          date: today);
      savings.withdraw(
          requestId: 'w1',
          goalId: japan,
          toWalletId: bank,
          amountMinor: 500000,
          date: today);
      savings.contribute(
          requestId: 'c2',
          goalId: phone,
          fromWalletId: bank,
          amountMinor: 800000,
          date: today);
      expect(() => core.deleteTransaction(core.transactionIdForRequest('c1')!),
          throwsFinance('goal_would_go_negative'));
      expect(savings.savedMinor(japan), 0);
      expect(savings.savedMinor(phone), 800000);
      expect(core.walletBalance(vault), 800000);
    });

    test('xóa lần rút thì tiền trở lại mục tiêu và trạng thái cập nhật', () {
      savings.contribute(
          requestId: 'c1',
          goalId: phone,
          fromWalletId: bank,
          amountMinor: 15000000,
          date: today);
      savings.withdraw(
          requestId: 'w1',
          goalId: phone,
          toWalletId: bank,
          amountMinor: 1000000,
          date: today);
      expect(savings.progress(phone).status, 'ACTIVE');
      core.deleteTransaction(core.transactionIdForRequest('w1')!);
      expect(savings.savedMinor(phone), 15000000);
      expect(savings.progress(phone).status, 'COMPLETED');
    });
  });

  group('Gợi ý số tiền', () {
    test('ví dụ trong đặc tả: thiếu 25 triệu, còn 125 ngày, 200.000 mỗi ngày',
        () {
      savings.contribute(
          requestId: req(),
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 5000000,
          date: today);
      // Từ 26/02/2027 đến 30/06/2027, tính cả hai đầu, là 125 ngày.
      final s = savings.suggestion(japan, '2027-02-26')!;
      expect(s.daysLeft, 125);
      expect(s.remainingMinor, 25000000);
      expect(s.dailyMinor, 200000);
      expect(s.weeklyMinor, 1388889); // 25 triệu / 18 tuần, làm tròn lên
      expect(s.monthlyMinor, 5000000); // 25 triệu / 5 tháng
    });

    test('ngày cuối cùng vẫn có gợi ý bằng toàn bộ số còn thiếu', () {
      final s = savings.suggestion(japan, '2027-06-30')!;
      expect(s.daysLeft, 1);
      expect(s.dailyMinor, 30000000);
    });

    test('quá hạn thì không có gợi ý', () {
      expect(savings.suggestion(japan, '2027-07-01'), isNull);
    });
  });

  group('Chuỗi ngày tiết kiệm', () {
    test('đếm ngày liên tiếp, hôm nay chưa tiết kiệm vẫn giữ chuỗi', () {
      for (final date in ['2026-11-09', '2026-11-10', '2026-11-11']) {
        savings.contribute(
            requestId: req(),
            goalId: japan,
            fromWalletId: bank,
            amountMinor: 100000,
            date: date);
      }
      expect(savings.currentStreak('2026-11-12'), 3);
      savings.contribute(
          requestId: req(),
          goalId: phone,
          fromWalletId: bank,
          amountMinor: 100000,
          date: '2026-11-12');
      expect(savings.currentStreak('2026-11-12'), 4);
      expect(savings.currentStreak('2026-11-14'), 0);
    });

    test('một ngày có nhiều lần góp chỉ tính một ngày', () {
      savings.contribute(
          requestId: req(),
          goalId: japan,
          fromWalletId: bank,
          amountMinor: 100000,
          date: today);
      savings.contribute(
          requestId: req(),
          goalId: phone,
          fromWalletId: bank,
          amountMinor: 100000,
          date: today);
      expect(savings.currentStreak(today), 1);
    });
  });

  group('Nâng cấp cơ sở dữ liệu', () {
    test('từ phiên bản 1 lên mới nhất giữ nguyên ví và giao dịch cũ', () {
      final legacy = FinanceCore(sqlite3.openInMemory());
      legacy.migrate(toVersion: 1);
      // Ghi thẳng theo cấu trúc phiên bản 1, như dữ liệu của bản app cũ.
      legacy.db.execute(
          'INSERT INTO wallets (id, name, type, currency_code, '
          "opening_balance_minor, created_at) VALUES ('old', 'Cũ', 'BANK', "
          "'VND', 1000000, 1)");
      legacy.db.execute(
          'INSERT INTO categories (id, name, type, created_at) '
          "VALUES ('food', 'Ăn uống', 'EXPENSE', 1)");
      const wallet = 'old';
      legacy.addExpense(
          requestId: 'old',
          walletId: wallet,
          amountMinor: 100000,
          date: '2026-10-01');
      legacy.migrate();
      expect(legacy.walletBalance(wallet), 900000);
      // Phiên bản 4 gán biểu tượng cho dữ liệu cũ.
      expect(legacy.wallet(wallet).icon, 'bank');
      expect(legacy.categories('EXPENSE').single.icon, 'food');
      final center = SavingsCenter(legacy);
      final box = legacy.createWallet(
          name: 'Tiết kiệm', type: 'SAVINGS', currencyCode: 'VND');
      final goal = center.createGoal(
          name: 'Mới',
          targetMinor: 100000,
          savingsWalletId: box,
          startDate: today,
          targetDate: '2027-01-01');
      center.contribute(
          requestId: 'new',
          goalId: goal,
          fromWalletId: wallet,
          amountMinor: 50000,
          date: today);
      expect(center.savedMinor(goal), 50000);
      legacy.close();
    });
  });

  group('Bất biến sau mọi thao tác (kiểm thử 18)', () {
    test('300 thao tác ngẫu nhiên không làm lệch số', () {
      final rng = Random(42);
      final oldVault = core.createWallet(
          name: 'Sổ tiết kiệm',
          type: 'SAVINGS',
          currencyCode: 'VND',
          openingBalanceMinor: 3000000);
      final emergency = savings.createGoal(
          name: 'Quỹ dự phòng',
          targetMinor: 8000000,
          savingsWalletId: oldVault,
          startDate: today,
          targetDate: '2027-12-31');
      final goals = {japan: vault, phone: vault, emergency: oldVault};
      final requests = <String>[];
      final vndOpening = 20000000 + 3000000;

      for (var i = 0; i < 300; i++) {
        final goalId = goals.keys.elementAt(rng.nextInt(goals.length));
        final amount = (rng.nextInt(20) + 1) * 100000;
        final id = 'op-$i';
        try {
          switch (rng.nextInt(6)) {
            case 0:
            case 1:
              savings.contribute(
                  requestId: id,
                  goalId: goalId,
                  fromWalletId: rng.nextBool() ? bank : cash,
                  amountMinor: amount,
                  date: today);
              requests.add(id);
            case 2:
              savings.withdraw(
                  requestId: id,
                  goalId: goalId,
                  toWalletId: rng.nextBool() ? bank : cash,
                  amountMinor: amount,
                  date: today);
              requests.add(id);
            case 3:
              savings.allocateUnassigned(
                  requestId: id,
                  goalId: goalId,
                  amountMinor: amount,
                  date: today);
            case 4:
              if (requests.isNotEmpty) {
                final txId = core.transactionIdForRequest(
                    requests[rng.nextInt(requests.length)])!;
                if (rng.nextBool()) {
                  core.deleteTransaction(txId);
                } else {
                  core.restoreTransaction(txId);
                }
              }
            case 5:
              core.addExpense(
                  requestId: id,
                  walletId: rng.nextBool() ? bank : cash,
                  amountMinor: amount,
                  date: today);
          }
        } on FinanceException {
          // Thao tác bị từ chối là bình thường; điều quan trọng là số liệu
          // vẫn đúng sau đó.
        }

        for (final box in [vault, oldVault]) {
          final balance = core.walletBalance(box);
          var allocated = 0;
          for (final entry in goals.entries.where((e) => e.value == box)) {
            final saved = savings.savedMinor(entry.key);
            expect(saved, greaterThanOrEqualTo(0), reason: 'bước $i');
            allocated += saved;
          }
          expect(allocated, lessThanOrEqualTo(balance), reason: 'bước $i');
          expect(savings.unallocatedMinor(box), balance - allocated,
              reason: 'bước $i');
        }
        // Ví thường được phép âm; ví tiết kiệm thì không bao giờ.
        for (final wallet in [vault, oldVault]) {
          expect(core.walletBalance(wallet), greaterThanOrEqualTo(0),
              reason: 'bước $i');
        }
        final summary =
            core.monthSummary(year: 2026, month: 11, currencyCode: 'VND');
        expect(core.totalAssetsByCurrency()['VND'],
            vndOpening + summary.incomeMinor - summary.expenseMinor,
            reason: 'bước $i');
      }
    });
  });

  test('lần góp tiết kiệm không sửa được qua sửa giao dịch', () {
    savings.contribute(
        requestId: req(),
        goalId: japan,
        fromWalletId: bank,
        amountMinor: 200000,
        date: today);
    final tx = core.transactions().first;
    expect(tx.isSavingsMove, isTrue);
    expect(
        () => core.updateTransaction(tx.id,
            walletId: bank,
            toWalletId: vault,
            amountMinor: 900000,
            date: today),
        throwsFinance('savings_not_editable'));
    expect(savings.savedMinor(japan), 200000);
  });
}

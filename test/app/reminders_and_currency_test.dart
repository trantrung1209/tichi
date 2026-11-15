import 'package:flutter_test/flutter_test.dart';
import 'package:tichi/app/local_reminders.dart';
import 'package:tichi/app/reminders.dart';
import 'package:tichi/app/seed.dart';
import 'package:tichi/app/store.dart';
import 'package:tichi/core/finance/finance_core.dart';
import 'package:tichi/core/savings/savings_center.dart';

/// Ghi lại các lần đặt nhắc để kiểm tra, không cần điện thoại.
class FakeReminders implements Reminders {
  ReminderRepeat? savingsRepeat;
  int? savingsWeekday;
  int? savingsMonthDay;
  String? savingsTitle;
  bool? expenseSkipToday;
  bool expenseCancelled = false;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleSavings({
    required ReminderRepeat repeat,
    required int hour,
    required int minute,
    int weekday = 7,
    int monthDay = 1,
    required String title,
    required String body,
  }) async {
    savingsRepeat = repeat;
    savingsWeekday = weekday;
    savingsMonthDay = monthDay;
    savingsTitle = title;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> scheduleExpenseCheck({
    required int hour,
    required int minute,
    required bool skipToday,
    required String title,
    required String body,
  }) async {
    expenseSkipToday = skipToday;
    expenseCancelled = false;
  }

  @override
  Future<void> cancelExpenseCheck() async => expenseCancelled = true;
}

String today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  group('Thời điểm nhắc kế tiếp', () {
    final now = DateTime(2026, 11, 15, 10, 0); // Chủ nhật

    test('hằng ngày: hôm nay nếu chưa tới giờ, bỏ qua hôm nay nếu cần', () {
      expect(
          nextReminderTime(
              now: now, repeat: ReminderRepeat.daily, hour: 20, minute: 0),
          DateTime(2026, 11, 15, 20, 0));
      expect(
          nextReminderTime(
              now: now,
              repeat: ReminderRepeat.daily,
              hour: 20,
              minute: 0,
              skipToday: true),
          DateTime(2026, 11, 16, 20, 0));
      expect(
          nextReminderTime(
              now: now, repeat: ReminderRepeat.daily, hour: 9, minute: 0),
          DateTime(2026, 11, 16, 9, 0));
    });

    test('hằng tuần: đúng thứ đã chọn', () {
      // Thứ Tư tới.
      expect(
          nextReminderTime(
              now: now,
              repeat: ReminderRepeat.weekly,
              hour: 20,
              minute: 0,
              weekday: 3),
          DateTime(2026, 11, 18, 20, 0));
      // Chủ nhật hôm nay đã qua giờ thì sang Chủ nhật tuần sau.
      expect(
          nextReminderTime(
              now: now,
              repeat: ReminderRepeat.weekly,
              hour: 8,
              minute: 0,
              weekday: 7),
          DateTime(2026, 11, 22, 8, 0));
    });

    test('hằng tháng: ngày đã qua thì sang tháng sau, qua năm mới đúng', () {
      expect(
          nextReminderTime(
              now: now,
              repeat: ReminderRepeat.monthly,
              hour: 20,
              minute: 0,
              monthDay: 1),
          DateTime(2026, 12, 1, 20, 0));
      expect(
          nextReminderTime(
              now: DateTime(2026, 12, 20),
              repeat: ReminderRepeat.monthly,
              hour: 20,
              minute: 0,
              monthDay: 5),
          DateTime(2027, 1, 5, 20, 0));
    });
  });

  group('Nhắc tiết kiệm theo tuần, tháng', () {
    test('lưu tần suất và đặt nhắc đúng loại', () async {
      final reminders = FakeReminders();
      final core = FinanceCore.inMemory();
      seedIfEmpty(core);
      final store = AppStore(core, reminders: reminders);
      await store.setReminder(enabled: true, frequency: 'weekly', weekday: 1);
      await store.syncReminder();
      expect(store.reminderFrequency, 'weekly');
      expect(reminders.savingsRepeat, ReminderRepeat.weekly);
      expect(reminders.savingsWeekday, 1);
      expect(reminders.savingsTitle, contains('Tuần'));

      await store.setReminder(enabled: true, frequency: 'monthly', monthDay: 31);
      await store.syncReminder();
      expect(store.reminderMonthDay, 28);
      expect(reminders.savingsRepeat, ReminderRepeat.monthly);
      expect(reminders.savingsMonthDay, 28);
    });

    test('chuỗi đếm theo tuần và theo tháng', () {
      final core = FinanceCore.inMemory();
      final savings = SavingsCenter(core);
      final bank = core.createWallet(
          name: 'Ngân hàng',
          type: 'BANK',
          currencyCode: 'VND',
          openingBalanceMinor: 10000000);
      final vault = core.createWallet(
          name: 'Ví tiết kiệm', type: 'SAVINGS', currencyCode: 'VND');
      final goal = savings.createGoal(
          name: 'Du lịch',
          targetMinor: 9000000,
          savingsWalletId: vault,
          startDate: '2026-09-01',
          targetDate: '2027-12-31');
      var n = 0;
      void give(String date) => savings.contribute(
          requestId: 'r${n++}',
          goalId: goal,
          fromWalletId: bank,
          amountMinor: 10000,
          date: date);
      // Ba tuần liên tiếp: tuần bắt đầu 26/10, 2/11 và 9/11/2026.
      give('2026-10-28');
      give('2026-11-03');
      give('2026-11-12');
      expect(savings.currentStreak('2026-11-13', period: 'weekly'), 3);
      // Tuần 16/11 chưa góp: chuỗi vẫn giữ tới tuần trước.
      expect(savings.currentStreak('2026-11-18', period: 'weekly'), 3);
      // Bỏ trọn tuần 16/11 thì chuỗi đứt.
      expect(savings.currentStreak('2026-11-25', period: 'weekly'), 0);
      // Tháng 9, 10, 11.
      give('2026-09-20');
      expect(savings.currentStreak('2026-12-05', period: 'monthly'), 3);
      expect(savings.currentStreak('2027-01-05', period: 'monthly'), 0);
    });
  });

  group('Nhắc ghi chi tiêu', () {
    test('hôm nay chưa ghi thì nhắc hôm nay; ghi rồi thì để ngày mai', () async {
      final reminders = FakeReminders();
      final core = FinanceCore.inMemory();
      seedIfEmpty(core);
      final store = AppStore(core, reminders: reminders);
      await store.setExpenseReminder(enabled: true);
      await store.syncReminder();
      expect(reminders.expenseSkipToday, isFalse);

      store.addExpense(
          requestId: 'lunch',
          walletId: store.spendingWallets().first.id,
          amountMinor: 50000,
          date: today());
      await store.syncReminder();
      expect(reminders.expenseSkipToday, isTrue);

      await store.setExpenseReminder(enabled: false);
      await store.syncReminder();
      expect(reminders.expenseCancelled, isTrue);
    });
  });

  group('Sửa lỗi loại tiền khi máy để tiếng Anh', () {
    test('ví mặc định USD đổi sang VND được, rồi ghi giao dịch VND', () {
      final core = FinanceCore.inMemory();
      seedIfEmpty(core, english: true, currency: 'USD');
      final store = AppStore(core);
      expect(store.spendingWallets().first.currencyCode, 'USD');

      store.useCurrency('VND');
      expect(store.baseCurrency, 'VND');
      for (final wallet in core.wallets()) {
        expect(wallet.currencyCode, 'VND');
      }
      final cash = store.spendingWallets().first;
      store.addExpense(
          requestId: 'x', walletId: cash.id, amountMinor: 55000, date: today());
      expect(core.walletBalance(cash.id), -55000);
    });

    test('ví đã có giao dịch thì khóa loại tiền', () {
      final core = FinanceCore.inMemory();
      final cash =
          core.createWallet(name: 'Cash', type: 'CASH', currencyCode: 'USD');
      core.setWalletCurrency(cash, 'VND', openingBalanceMinor: 200000);
      expect(core.wallet(cash).currencyCode, 'VND');
      expect(core.walletBalance(cash), 200000);
      core.addIncome(
          requestId: 'a', walletId: cash, amountMinor: 1000, date: today());
      expect(() => core.setWalletCurrency(cash, 'USD'),
          throwsA(isA<FinanceException>()
              .having((e) => e.code, 'code', 'wallet_in_use')));
      final store = AppStore(core);
      expect(store.walletsConvertibleTo('USD'), isEmpty);
    });
  });
}

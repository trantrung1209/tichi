/// Cầu nối giữa phần lõi và giao diện. Mọi thao tác ghi đi qua đây để màn
/// hình được vẽ lại sau khi dữ liệu đổi.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../core/budget/budget_service.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import '../core/savings/savings_center.dart';
import 'reminders.dart';
import '../core/l10n.dart';

class HomeSummary {
  const HomeSummary({
    required this.baseCurrency,
    required this.totalMinor,
    required this.savingsMinor,
    required this.spendingMinor,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.missingRate,
    required this.goal,
    required this.suggestion,
    required this.recent,
  });

  final String baseCurrency;
  final int totalMinor;
  final int savingsMinor;
  final int spendingMinor;
  final int incomeMinor;
  final int expenseMinor;

  /// Có ví USD mà chưa nhập tỷ giá: các tổng trên chưa tính phần USD.
  final bool missingRate;
  final GoalProgress? goal;
  final SavingsSuggestion? suggestion;
  final List<TransactionView> recent;
}

class MonthTotals {
  const MonthTotals(this.incomeMinor, this.expenseMinor, this.missingRate);

  final int incomeMinor;
  final int expenseMinor;
  final bool missingRate;
}

class AppStore extends ChangeNotifier {
  AppStore(this.core, {this.reminders = const NoReminders()})
      : savings = SavingsCenter(core),
        budgets = BudgetService(core) {
    _migrateSettings();
  }

  /// Bản 1.3 đổi giờ nhắc ghi chi tiêu mặc định từ 21:00 sang 20:00. Người
  /// dùng cũ vẫn để giờ mặc định thì chuyển theo, một lần duy nhất.
  void _migrateSettings() {
    if (core.getSetting('expense_time_migrated') != null) return;
    if (core.getSetting('expense_reminder_time') == '21:00') {
      core.setSetting('expense_reminder_time', '20:00');
    }
    core.setSetting('expense_time_migrated', '1');
  }

  final FinanceCore core;
  final SavingsCenter savings;
  final BudgetService budgets;
  final Reminders reminders;
  final Random _random = Random.secure();

  /// Chạy một thao tác ghi rồi báo các màn hình vẽ lại. Nội dung nhắc tiết
  /// kiệm cũng được cập nhật theo số liệu mới.
  T _write<T>(T Function() action) {
    final result = action();
    notifyListeners();
    unawaited(syncReminder());
    return result;
  }

  /// Báo các màn hình đọc lại toàn bộ dữ liệu, ví dụ sau khi khôi phục.
  void reloadAll() {
    notifyListeners();
    unawaited(syncReminder());
  }

  // ----------------------------------------------------- Lần đầu dùng app

  bool get onboardingDone => core.getSetting('onboarding_done') == '1';

  void completeOnboarding() =>
      _write(() => core.setSetting('onboarding_done', '1'));

  // ------------------------------------------------------- Tên người dùng

  /// Độ dài tối đa của tên gọi.
  static const maxNameLength = 30;

  /// Tên gọi người dùng đã xác nhận, null nếu chưa có.
  String? get userName {
    final value = core.getSetting('user_name')?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Lưu tên gọi sau khi bỏ khoảng trắng thừa. Tên rỗng thì báo lỗi.
  void setUserName(String name) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) {
      throw FinanceException('invalid_name', tr('Hãy nhập tên gọi của bạn', 'Please enter what we should call you'));
    }
    if (clean.characters.length > maxNameLength) {
      throw FinanceException('name_too_long',
          tr('Tên gọi tối đa $maxNameLength ký tự', 'Name can be at most $maxNameLength characters'));
    }
    _write(() => core.setSetting('user_name', clean));
  }

  // ------------------------------------------------------- Nhắc sao lưu

  /// Đã sao lưu rồi thì nhắc lại sau chừng này ngày.
  static const backupEveryDays = 14;

  /// Chưa sao lưu lần nào thì nhắc sau chừng này ngày kể từ giao dịch đầu.
  static const firstBackupAfterDays = 3;

  static int _daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  /// Ngày sao lưu gần nhất dạng "YYYY-MM-DD", null nếu chưa sao lưu.
  String? get lastBackupAt => core.getSetting('last_backup_at');

  /// Có nên hiện thẻ nhắc sao lưu ở Trang chủ không. Dữ liệu Tichi chỉ nằm
  /// trên máy, nên mất máy mà chưa sao lưu là mất hết.
  bool backupDue(DateTime now) {
    final snoozed = core.getSetting('backup_snoozed_until');
    if (snoozed != null && dateKey(now).compareTo(snoozed) < 0) return false;
    final last = lastBackupAt;
    if (last != null) {
      return _daysBetween(DateTime.parse(last), now) >= backupEveryDays;
    }
    final first = core.db
        .select('SELECT MIN(created_at) AS first FROM transactions '
            'WHERE deleted_at IS NULL')
        .first['first'] as int?;
    if (first == null) return false;
    final firstDay = DateTime.fromMillisecondsSinceEpoch(first, isUtc: true)
        .toLocal();
    return _daysBetween(firstDay, now) >= firstBackupAfterDays;
  }

  /// Ẩn thẻ nhắc sao lưu trong 7 ngày.
  void snoozeBackupReminder(DateTime now) => _write(() => core.setSetting(
      'backup_snoozed_until', dateKey(now.add(const Duration(days: 7)))));

  /// Ghi nhận vừa sao lưu xong.
  void markBackedUp(DateTime now) =>
      _write(() => core.setSetting('last_backup_at', dateKey(now)));

  // ------------------------------------------------------- Ngôn ngữ

  /// 'system' (theo máy), 'vi' hoặc 'en'.
  String get language {
    final value = core.getSetting('language');
    return value == 'vi' || value == 'en' ? value! : 'system';
  }

  void setLanguage(String value) {
    if (value != 'system' && value != 'vi' && value != 'en') {
      throw ArgumentError.value(value, 'value');
    }
    _write(() => core.setSetting('language', value));
  }

  /// Có dùng tiếng Anh không. Theo máy: máy để tiếng Việt thì dùng tiếng
  /// Việt, còn lại dùng tiếng Anh.
  bool resolveEnglish(Locale deviceLocale) => switch (language) {
        'vi' => false,
        'en' => true,
        _ => deviceLocale.languageCode != 'vi',
      };

  // ------------------------------------------------------- Giao diện

  /// 'system' (theo máy), 'light' (sáng) hoặc 'dark' (tối).
  String get themeMode {
    final value = core.getSetting('theme_mode');
    return value == 'light' || value == 'dark' ? value! : 'system';
  }

  void setThemeMode(String mode) {
    if (mode != 'system' && mode != 'light' && mode != 'dark') {
      throw ArgumentError.value(mode, 'mode');
    }
    _write(() => core.setSetting('theme_mode', mode));
  }

  // ------------------------------------------------------- Nhắc tiết kiệm

  bool get reminderEnabled => core.getSetting('reminder_enabled') == '1';

  static (int, int) _time(String? value, String fallback) {
    final parts = (value ?? fallback).split(':');
    return (int.tryParse(parts.first) ?? 20,
        int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
  }

  static String _timeText(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  /// Giờ nhắc tiết kiệm, mặc định 20:00.
  (int, int) get reminderTime =>
      _time(core.getSetting('reminder_time'), '20:00');

  /// Tần suất nhắc tiết kiệm: 'daily', 'weekly' hoặc 'monthly'.
  String get reminderFrequency {
    final value = core.getSetting('reminder_frequency');
    return value == 'weekly' || value == 'monthly' ? value! : 'daily';
  }

  /// Ngày trong tuần để nhắc (1 = thứ Hai … 7 = Chủ nhật), mặc định Chủ nhật.
  int get reminderWeekday =>
      (int.tryParse(core.getSetting('reminder_weekday') ?? '') ?? 7)
          .clamp(1, 7);

  /// Ngày trong tháng để nhắc (1–28), mặc định ngày 1.
  int get reminderMonthDay =>
      (int.tryParse(core.getSetting('reminder_monthday') ?? '') ?? 1)
          .clamp(1, 28);

  Future<bool> setReminder({
    required bool enabled,
    int? hour,
    int? minute,
    String? frequency,
    int? weekday,
    int? monthDay,
  }) async {
    if (enabled && !await reminders.requestPermission()) return false;
    final (oldHour, oldMinute) = reminderTime;
    _write(() {
      core.setSetting('reminder_enabled', enabled ? '1' : '0');
      core.setSetting(
          'reminder_time', _timeText(hour ?? oldHour, minute ?? oldMinute));
      if (frequency != null) {
        if (!const ['daily', 'weekly', 'monthly'].contains(frequency)) {
          throw ArgumentError.value(frequency, 'frequency');
        }
        core.setSetting('reminder_frequency', frequency);
      }
      if (weekday != null) {
        core.setSetting('reminder_weekday', '${weekday.clamp(1, 7)}');
      }
      if (monthDay != null) {
        core.setSetting('reminder_monthday', '${monthDay.clamp(1, 28)}');
      }
    });
    return true;
  }

  // ---------------------------------------------------- Nhắc ghi chi tiêu

  bool get expenseReminderEnabled =>
      core.getSetting('expense_reminder_enabled') == '1';

  /// Giờ nhắc ghi chi tiêu, mặc định 20:00.
  (int, int) get expenseReminderTime =>
      _time(core.getSetting('expense_reminder_time'), '20:00');

  Future<bool> setExpenseReminder(
      {required bool enabled, int? hour, int? minute}) async {
    if (enabled && !await reminders.requestPermission()) return false;
    final (oldHour, oldMinute) = expenseReminderTime;
    _write(() {
      core.setSetting('expense_reminder_enabled', enabled ? '1' : '0');
      core.setSetting('expense_reminder_time',
          _timeText(hour ?? oldHour, minute ?? oldMinute));
    });
    return true;
  }

  /// Ngày [day] đã ghi khoản CHI nào chưa. Khoản thu, chuyển ví hay góp tiết
  /// kiệm không tính, vì nhắc này là để không quên ghi chi tiêu.
  bool hasExpenseOn(DateTime day) => core.db.select(
      "SELECT 1 FROM transactions WHERE deleted_at IS NULL "
      "AND type = 'EXPENSE' AND transaction_date = ? LIMIT 1",
      [dateKey(day)]).isNotEmpty;

  /// Kỳ chứa [now] (hôm nay, tuần thứ Hai–Chủ nhật, hoặc tháng, theo
  /// [frequency]) đã có lần góp tiền vào ví tiết kiệm nào chưa.
  bool hasSavedInPeriod(DateTime now, String frequency) {
    final day = DateTime(now.year, now.month, now.day);
    final (DateTime start, DateTime end) = switch (frequency) {
      'weekly' => (
          DateTime(day.year, day.month, day.day - (day.weekday - 1)),
          DateTime(day.year, day.month, day.day + (7 - day.weekday)),
        ),
      'monthly' => (
          DateTime(day.year, day.month, 1),
          DateTime(day.year, day.month + 1, 0),
        ),
      _ => (day, day),
    };
    return core.db.select(
        "SELECT 1 FROM transactions t JOIN wallets w "
        "ON w.id = t.destination_wallet_id "
        "WHERE t.deleted_at IS NULL AND w.type = 'SAVINGS' "
        "AND t.transaction_date BETWEEN ? AND ? LIMIT 1",
        [dateKey(start), dateKey(end)]).isNotEmpty;
  }

  /// Đặt lại các thông báo theo cài đặt và số liệu mới nhất.
  Future<void> syncReminder() async {
    try {
      await _syncSavingsReminder();
    } catch (_) {
      // Nhắc là phần phụ: lỗi đặt thông báo không được làm hỏng thao tác chính.
    }
    try {
      await _syncExpenseReminder();
    } catch (_) {}
  }

  Future<void> _syncSavingsReminder() async {
    if (!reminderEnabled) {
      await reminders.cancel();
      return;
    }
    final (hour, minute) = reminderTime;
    final frequency = reminderFrequency;
    GoalProgress? goal;
    for (final candidate in savings.goals()) {
      if (candidate.status == 'ACTIVE') {
        goal = candidate;
        break;
      }
    }
    final suggestion = goal == null
        ? null
        : savings.suggestion(goal.goalId, dateKey(DateTime.now()));
    final String title;
    final String body;
    switch (frequency) {
      case 'weekly':
        title = tr('Tuần này bạn đã tiết kiệm chưa?', 'Have you saved this week?');
        body = (goal != null && suggestion != null)
            ? tr(
                'Tuần này hãy dành ${formatMinor(suggestion.weeklyMinor, goal.currencyCode)} cho mục tiêu ${goal.name} nhé!',
                'Set aside ${formatMinor(suggestion.weeklyMinor, goal.currencyCode)} for ${goal.name} this week!')
            : tr('Mở Tichi để ghi lại khoản tiết kiệm tuần này.',
                'Open Tichi to record this week\'s saving.');
      case 'monthly':
        title =
            tr('Tháng này bạn đã tiết kiệm chưa?', 'Have you saved this month?');
        body = (goal != null && suggestion != null)
            ? tr(
                'Tháng này hãy dành ${formatMinor(suggestion.monthlyMinor, goal.currencyCode)} cho mục tiêu ${goal.name} nhé!',
                'Set aside ${formatMinor(suggestion.monthlyMinor, goal.currencyCode)} for ${goal.name} this month!')
            : tr('Mở Tichi để ghi lại khoản tiết kiệm tháng này.',
                'Open Tichi to record this month\'s saving.');
      default:
        title = tr('Bạn đã tiết kiệm hôm nay chưa?', 'Have you saved today?');
        body = (goal != null && suggestion != null)
            ? tr(
                'Hãy dành ${formatMinor(suggestion.dailyMinor, goal.currencyCode)} cho mục tiêu ${goal.name} nhé!',
                'Set aside ${formatMinor(suggestion.dailyMinor, goal.currencyCode)} for ${goal.name} today!')
            : tr('Mở Tichi để ghi lại khoản tiết kiệm hôm nay.',
                'Open Tichi to record today\'s saving.');
    }
    await reminders.scheduleSavings(
      repeat: switch (frequency) {
        'weekly' => ReminderRepeat.weekly,
        'monthly' => ReminderRepeat.monthly,
        _ => ReminderRepeat.daily,
      },
      hour: hour,
      minute: minute,
      weekday: reminderWeekday,
      monthDay: reminderMonthDay,
      skipCurrentPeriod: hasSavedInPeriod(DateTime.now(), frequency),
      title: title,
      body: body,
    );
  }

  Future<void> _syncExpenseReminder() async {
    if (!expenseReminderEnabled) {
      await reminders.cancelExpenseCheck();
      return;
    }
    final (hour, minute) = expenseReminderTime;
    await reminders.scheduleExpenseCheck(
      hour: hour,
      minute: minute,
      skipToday: hasExpenseOn(DateTime.now()),
      title: tr('Hôm nay bạn chưa ghi khoản chi nào',
          'No expenses logged today'),
      body: tr('Ghi lại chi tiêu hôm nay chỉ mất vài giây.',
          'Logging today\'s spending only takes a few seconds.'),
    );
  }

  // ------------------------------------------------------------ Cài đặt

  String get baseCurrency => core.getSetting('base_currency') ?? 'VND';

  void setBaseCurrency(String currency) =>
      _write(() => core.setSetting('base_currency', currency));

  /// Các ví chưa dùng, chưa có số dư và đang ở loại tiền khác [currency]:
  /// đổi được sang [currency] mà không ảnh hưởng số liệu nào.
  List<WalletInfo> walletsConvertibleTo(String currency) => [
        for (final wallet in core.wallets())
          if (wallet.currencyCode != currency &&
              !core.walletInUse(wallet.id) &&
              core.openingBalance(wallet.id) == 0)
            wallet,
      ];

  /// Đổi các ví chưa dùng sang [currency] và đặt luôn loại tiền hiển thị.
  void useCurrency(String currency) => _write(() {
        core.runInTransaction(() {
          for (final wallet in walletsConvertibleTo(currency)) {
            core.setWalletCurrency(wallet.id, currency);
          }
          core.setSetting('base_currency', currency);
        });
      });

  bool walletInUse(String walletId) => core.walletInUse(walletId);

  void setWalletCurrency(String walletId, String currency,
          {int openingBalanceMinor = 0}) =>
      _write(() => core.setWalletCurrency(walletId, currency,
          openingBalanceMinor: openingBalanceMinor));

  /// Đổi về loại tiền hiển thị. Null nếu cần tỷ giá mà chưa có.
  int? toBase(int amountMinor, String currency) =>
      convertMinor(amountMinor, currency, baseCurrency, usdVndRate: usdVndRate);

  /// Số đồng cho 1 USD, do người dùng nhập.
  int? get usdVndRate => int.tryParse(core.getSetting('rate_usd_vnd') ?? '');

  void setUsdVndRate(int rate) {
    if (rate <= 0) {
      throw FinanceException('invalid_rate', tr('Tỷ giá phải lớn hơn 0', 'The rate must be greater than 0'));
    }
    core.setSetting('rate_usd_vnd', '$rate');
    notifyListeners();
  }

  bool get hasUsdWallet =>
      core.wallets(includeArchived: true).any((w) => w.currencyCode == 'USD');

  // ------------------------------------------------------------- Đọc

  HomeSummary homeSummary(DateTime now) {
    final base = baseCurrency;
    final rate = usdVndRate;
    var missing = false;
    int toBase(int amount, String currency) {
      final converted = convertMinor(amount, currency, base, usdVndRate: rate);
      if (converted == null) {
        missing = true;
        return 0;
      }
      return converted;
    }

    var savingsTotal = 0;
    var spendingTotal = 0;
    for (final wallet in core.wallets(includeArchived: true)) {
      final value = toBase(wallet.balanceMinor, wallet.currencyCode);
      if (wallet.isSavings) {
        savingsTotal += value;
      } else {
        spendingTotal += value;
      }
    }

    final month = monthTotals(now.year, now.month);
    GoalProgress? goal;
    for (final candidate in savings.goals()) {
      if (candidate.status == 'ACTIVE') {
        goal = candidate;
        break;
      }
    }
    return HomeSummary(
      baseCurrency: base,
      totalMinor: savingsTotal + spendingTotal,
      savingsMinor: savingsTotal,
      spendingMinor: spendingTotal,
      incomeMinor: month.incomeMinor,
      expenseMinor: month.expenseMinor,
      missingRate: missing || month.missingRate,
      goal: goal,
      suggestion:
          goal == null ? null : savings.suggestion(goal.goalId, dateKey(now)),
      recent: core.transactions(limit: 5),
    );
  }

  /// Thu và chi của một tháng, quy về loại tiền hiển thị.
  MonthTotals monthTotals(int year, int month) {
    final base = baseCurrency;
    final rate = usdVndRate;
    var income = 0;
    var expense = 0;
    var missing = false;
    for (final currency in const ['VND', 'USD']) {
      final summary =
          core.monthSummary(year: year, month: month, currencyCode: currency);
      final convertedIncome =
          convertMinor(summary.incomeMinor, currency, base, usdVndRate: rate);
      final convertedExpense =
          convertMinor(summary.expenseMinor, currency, base, usdVndRate: rate);
      if (convertedIncome == null || convertedExpense == null) {
        missing = true;
        continue;
      }
      income += convertedIncome;
      expense += convertedExpense;
    }
    return MonthTotals(income, expense, missing);
  }

  /// Ví dùng để ghi thu, chi, chuyển: không gồm ví tiết kiệm và ví đã lưu trữ.
  List<WalletInfo> spendingWallets() =>
      core.wallets().where((w) => !w.isSavings).toList();

  List<CategoryInfo> categories(String type) => core.categories(type);

  List<TransactionView> transactions({String? monthPrefix, int? limit}) =>
      core.transactions(monthPrefix: monthPrefix, limit: limit);

  /// Danh mục xếp theo số lần dùng gần đây, hay dùng nhất đứng đầu. Danh mục
  /// chưa dùng giữ thứ tự sẵn có.
  List<CategoryInfo> categoriesByUsage(String type) {
    final list = core.categories(type);
    final counts = <String, int>{};
    for (final tx in core.transactions(limit: 300)) {
      final id = tx.categoryId;
      if (tx.type == type && id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    final order = {for (var i = 0; i < list.length; i++) list[i].id: i};
    return list.toList()
      ..sort((a, b) {
        final byCount = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
        return byCount != 0 ? byCount : order[a.id]!.compareTo(order[b.id]!);
      });
  }

  /// Ví nên chọn sẵn cho loại giao dịch [type]: ví của lần ghi gần nhất cùng
  /// loại, nếu không có thì ví chi tiêu đầu tiên.
  String? suggestedWalletId(String type) {
    final wallets = spendingWallets();
    if (wallets.isEmpty) return null;
    final ids = {for (final w in wallets) w.id};
    for (final tx in core.transactions(limit: 50)) {
      if (tx.type != type || tx.isSavingsMove) continue;
      final id =
          type == 'INCOME' ? tx.destinationWalletId : tx.sourceWalletId;
      if (id != null && ids.contains(id)) return id;
    }
    return wallets.first.id;
  }

  /// Tối đa 3 số tiền hay ghi nhất với loại [type] (ưu tiên danh mục
  /// [categoryId]) và loại tiền [currency].
  List<int> frequentAmounts(String type, String? categoryId, String currency) {
    final inCategory = <int, int>{};
    final inType = <int, int>{};
    for (final tx in core.transactions(limit: 300)) {
      if (tx.type != type || tx.isSavingsMove || tx.currency != currency) {
        continue;
      }
      inType[tx.amountMinor] = (inType[tx.amountMinor] ?? 0) + 1;
      if (categoryId != null && tx.categoryId == categoryId) {
        inCategory[tx.amountMinor] = (inCategory[tx.amountMinor] ?? 0) + 1;
      }
    }
    List<int> top(Map<int, int> counts) => (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .map((e) => e.key)
        .toList();
    final result = <int>[...top(inCategory)];
    for (final amount in top(inType)) {
      if (result.length >= 3) break;
      if (!result.contains(amount)) result.add(amount);
    }
    return result.take(3).toList();
  }

  // ------------------------------------------------------------- Ghi

  /// Mã dùng một lần cho mỗi lần mở màn hình nhập, để bấm Lưu nhiều lần chỉ
  /// tạo một giao dịch.
  String newRequestId() {
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String addIncome({
    required String requestId,
    required String walletId,
    required int amountMinor,
    required String date,
    String? categoryId,
    String? note,
  }) {
    final id = core.addIncome(
        requestId: requestId,
        walletId: walletId,
        amountMinor: amountMinor,
        date: date,
        categoryId: categoryId,
        note: note);
    notifyListeners();
    unawaited(syncReminder());
    return id;
  }

  String addExpense({
    required String requestId,
    required String walletId,
    required int amountMinor,
    required String date,
    String? categoryId,
    String? note,
  }) {
    final id = core.addExpense(
        requestId: requestId,
        walletId: walletId,
        amountMinor: amountMinor,
        date: date,
        categoryId: categoryId,
        note: note);
    notifyListeners();
    unawaited(syncReminder());
    return id;
  }

  /// Sửa một khoản thu, chi hoặc chuyển ví thường.
  void updateTransaction(
    String transactionId, {
    required String walletId,
    String? toWalletId,
    required int amountMinor,
    int? destinationAmountMinor,
    required String date,
    String? categoryId,
    String? note,
  }) =>
      _write(() => core.updateTransaction(transactionId,
          walletId: walletId,
          toWalletId: toWalletId,
          amountMinor: amountMinor,
          destinationAmountMinor: destinationAmountMinor,
          date: date,
          categoryId: categoryId,
          note: note));

  String transfer({
    required String requestId,
    required String fromWalletId,
    required String toWalletId,
    required int amountMinor,
    required String date,
    int? destinationAmountMinor,
    String? note,
  }) {
    final id = core.transfer(
        requestId: requestId,
        fromWalletId: fromWalletId,
        toWalletId: toWalletId,
        amountMinor: amountMinor,
        destinationAmountMinor: destinationAmountMinor,
        date: date,
        note: note);
    notifyListeners();
    unawaited(syncReminder());
    return id;
  }

  void deleteTransaction(String transactionId) {
    core.deleteTransaction(transactionId);
    notifyListeners();
    unawaited(syncReminder());
  }

  void restoreTransaction(String transactionId) {
    core.restoreTransaction(transactionId);
    notifyListeners();
    unawaited(syncReminder());
  }

  // ---------------------------------------------------------------- Ví

  List<WalletInfo> allWallets({bool includeArchived = false}) =>
      core.wallets(includeArchived: includeArchived);

  List<WalletInfo> savingsWallets() =>
      core.wallets().where((w) => w.isSavings).toList();

  WalletInfo wallet(String walletId) => core.wallet(walletId);

  String createWallet({
    required String name,
    required String type,
    required String currencyCode,
    required int openingBalanceMinor,
    required String icon,
    required String color,
  }) =>
      _write(() => core.createWallet(
          name: name,
          type: type,
          currencyCode: currencyCode,
          openingBalanceMinor: openingBalanceMinor,
          icon: icon,
          color: color));

  void updateWallet(String walletId,
          {required String name, required String icon, required String color}) =>
      _write(() =>
          core.updateWallet(walletId, name: name, icon: icon, color: color));

  void setWalletArchived(String walletId, bool archived) =>
      _write(() => core.setWalletArchived(walletId, archived));

  int openingBalance(String walletId) => core.openingBalance(walletId);

  void setOpeningBalance(String walletId, int amountMinor) =>
      _write(() => core.setOpeningBalance(walletId, amountMinor));

  // ----------------------------------------------------------- Danh mục

  List<CategoryInfo> allCategories(String type) =>
      core.categories(type, includeArchived: true);

  String createCategory({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) =>
      _write(() => core.createCategory(
          name: name, type: type, icon: icon, color: color));

  void updateCategory(String categoryId,
          {required String name, required String icon, required String color}) =>
      _write(() => core.updateCategory(categoryId,
          name: name, icon: icon, color: color));

  void setCategoryArchived(String categoryId, bool archived) =>
      _write(() => core.setCategoryArchived(categoryId, archived));

  // ----------------------------------------------------------- Tiết kiệm

  List<GoalProgress> goals() => savings.goals();

  GoalProgress goal(String goalId) => savings.progress(goalId);

  List<GoalEvent> goalHistory(String goalId) => savings.history(goalId);

  SavingsSuggestion? suggestion(String goalId, DateTime today) =>
      savings.suggestion(goalId, dateKey(today));

  /// Chuỗi tiết kiệm, đếm theo đúng tần suất nhắc (ngày, tuần hoặc tháng).
  int streak(DateTime today) =>
      savings.currentStreak(dateKey(today), period: reminderFrequency);

  int unallocated(String savingsWalletId) =>
      savings.unallocatedMinor(savingsWalletId);

  String createGoal({
    required String name,
    required int targetMinor,
    required String savingsWalletId,
    required String startDate,
    required String targetDate,
    required int priority,
    required String icon,
  }) =>
      _write(() => savings.createGoal(
          name: name,
          targetMinor: targetMinor,
          savingsWalletId: savingsWalletId,
          startDate: startDate,
          targetDate: targetDate,
          priority: priority,
          icon: icon));

  void updateGoal(
    String goalId, {
    required String name,
    required int targetMinor,
    required String targetDate,
    required int priority,
    required String icon,
  }) =>
      _write(() => savings.updateGoal(goalId,
          name: name,
          targetMinor: targetMinor,
          targetDate: targetDate,
          priority: priority,
          icon: icon));

  void deleteGoal(String goalId) => _write(() => savings.deleteGoal(goalId));

  void contribute({
    required String requestId,
    required String goalId,
    required String fromWalletId,
    required int amountMinor,
    required String date,
  }) =>
      _write(() => savings.contribute(
          requestId: requestId,
          goalId: goalId,
          fromWalletId: fromWalletId,
          amountMinor: amountMinor,
          date: date));

  void withdraw({
    required String requestId,
    required String goalId,
    required String toWalletId,
    required int amountMinor,
    required String date,
  }) =>
      _write(() => savings.withdraw(
          requestId: requestId,
          goalId: goalId,
          toWalletId: toWalletId,
          amountMinor: amountMinor,
          date: date));

  void allocate({
    required String requestId,
    required String goalId,
    required int amountMinor,
    required String date,
  }) =>
      _write(() => savings.allocateUnassigned(
          requestId: requestId,
          goalId: goalId,
          amountMinor: amountMinor,
          date: date));

  // ----------------------------------------------------------- Ngân sách

  List<BudgetStatus> budgetStatuses(int year, int month) => budgets.statuses(
      year: year, month: month, currencyCode: baseCurrency);

  void setBudget({String? categoryId, required int amountMinor}) =>
      _write(() => budgets.setBudget(
          categoryId: categoryId,
          currencyCode: baseCurrency,
          amountMinor: amountMinor));

  void deleteBudget(String budgetId) =>
      _write(() => budgets.deleteBudget(budgetId));
}

/// Đưa [AppStore] xuống các màn hình. Màn hình gọi [of] sẽ tự vẽ lại khi dữ
/// liệu đổi.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Lấy store mà không vẽ lại khi dữ liệu đổi; dùng trong hàm xử lý bấm nút.
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

/// Lời nhắn dễ hiểu cho một lỗi nghiệp vụ.
String friendlyError(Object error) {
  if (error is InsufficientFundsException) {
    return tr('Ví không đủ tiền, còn thiếu '
        '${formatMinor(error.shortfallMinor, error.currency ?? 'VND')}.', 'Not enough money in this wallet, short by ' '${formatMinor(error.shortfallMinor, error.currency ?? 'VND')}.');
  }
  if (error is FinanceException) {
    if (!L10n.en) return error.message;
    return _englishErrors[error.code] ??
        'This action isn\'t allowed. Nothing was saved.';
  }
  return tr('Có lỗi xảy ra, chưa có gì được lưu.', 'Something went wrong. Nothing was saved.');
}

/// Lỗi nghiệp vụ bằng tiếng Anh, theo mã lỗi. Lớp lõi chỉ có câu tiếng Việt.
const Map<String, String> _englishErrors = {
  'amount_mismatch': 'For the same currency, the received amount must equal the sent amount.',
  'amount_too_large': 'The amount is too large.',
  'backup_corrupt': 'The backup file is damaged.',
  'backup_inconsistent': 'The data in the backup file doesn\'t add up.',
  'backup_invalid': 'This is not a Tichi backup file.',
  'backup_too_new': 'This backup was made with a newer Tichi. Please update the app first.',
  'category_not_found': 'Category not found.',
  'currency_mismatch': 'Saving and withdrawing only work between wallets in the same currency.',
  'destination_amount_required': 'Different currencies: enter the amount the wallet receives.',
  'exceeds_goal_savings': 'That is more than this goal has saved.',
  'exceeds_unallocated': 'That is more than the unassigned money in this wallet.',
  'goal_archived': 'This goal is archived.',
  'goal_not_found': 'Goal not found.',
  'goal_would_go_negative': 'This would make a goal\'s savings negative.',
  'invalid_amount': 'The amount must be greater than 0.',
  'invalid_category_type': 'Invalid category type.',
  'invalid_date': 'Invalid date.',
  'invalid_dates': 'The target date must be after the start date.',
  'invalid_name': 'Please enter a name.',
  'invalid_rate': 'The rate must be greater than 0.',
  'invalid_wallet_type': 'Invalid wallet type.',
  'name_too_long': 'The name is too long (30 characters max).',
  'not_expense_category': 'Budgets are only for expense categories.',
  'not_savings_wallet': 'A goal must use a savings wallet.',
  'same_wallet': 'Choose two different wallets.',
  'savings_not_editable': 'Savings deposits and withdrawals can\'t be edited. Delete it and redo it instead.',
  'savings_overallocated': 'Goals would hold more than the wallet balance.',
  'transaction_deleted': 'This transaction was deleted.',
  'transaction_not_found': 'Transaction not found.',
  'unsupported_currency': 'This currency isn\'t supported yet.',
  'wallet_archived': 'This wallet is archived.',
  'wallet_in_use': 'This wallet already has transactions, so its currency can\'t be changed.',
  'wallet_has_goals': 'This wallet still has savings goals. Delete or move them first.',
  'wallet_not_found': 'Wallet not found.',
  'weak_password': 'The password needs at least 6 characters.',
  'would_go_negative': 'This would make the savings wallet negative.',
  'wrong_password': 'Wrong password, or the backup file was changed.',
  'income_into_savings': 'Money goes into a savings wallet only through Savings.',
  'expense_from_savings': 'You can\'t spend directly from a savings wallet.',
  'transfer_from_savings': 'Money leaves a savings wallet only through Withdraw.',
  'transfer_into_savings': 'Money goes into a savings wallet only through Savings.',
};

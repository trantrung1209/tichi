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
        budgets = BudgetService(core);

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

  /// Giờ nhắc, mặc định 20:00.
  (int, int) get reminderTime {
    final parts = (core.getSetting('reminder_time') ?? '20:00').split(':');
    return (int.tryParse(parts[0]) ?? 20, int.tryParse(parts[1]) ?? 0);
  }

  /// Bật hoặc tắt nhắc. Trả về false nếu người dùng không cho hiện thông báo.
  Future<bool> setReminder({required bool enabled, int? hour, int? minute}) async {
    if (enabled && !await reminders.requestPermission()) return false;
    final (oldHour, oldMinute) = reminderTime;
    final h = hour ?? oldHour;
    final m = minute ?? oldMinute;
    _write(() {
      core.setSetting('reminder_enabled', enabled ? '1' : '0');
      core.setSetting('reminder_time',
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
    });
    return true;
  }

  /// Đặt lại thông báo theo mục tiêu ưu tiên và số gợi ý hôm nay.
  Future<void> syncReminder() async {
    try {
      if (!reminderEnabled) {
        await reminders.cancel();
        return;
      }
      final (hour, minute) = reminderTime;
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
      final body = (goal != null && suggestion != null)
          ? 'Hãy dành ${formatMinor(suggestion.dailyMinor, goal.currencyCode)} '
              'cho mục tiêu ${goal.name} nhé!'
          : 'Mở Tichi để ghi lại khoản tiết kiệm hôm nay.';
      await reminders.scheduleDaily(
        hour: hour,
        minute: minute,
        title: 'Bạn đã tiết kiệm hôm nay chưa?',
        body: body,
      );
    } catch (_) {
      // Nhắc là phần phụ: lỗi đặt thông báo không được làm hỏng thao tác chính.
    }
  }

  // ------------------------------------------------------------ Cài đặt

  String get baseCurrency => core.getSetting('base_currency') ?? 'VND';

  void setBaseCurrency(String currency) =>
      _write(() => core.setSetting('base_currency', currency));

  /// Đổi về loại tiền hiển thị. Null nếu cần tỷ giá mà chưa có.
  int? toBase(int amountMinor, String currency) =>
      convertMinor(amountMinor, currency, baseCurrency, usdVndRate: usdVndRate);

  /// Số đồng cho 1 USD, do người dùng nhập.
  int? get usdVndRate => int.tryParse(core.getSetting('rate_usd_vnd') ?? '');

  void setUsdVndRate(int rate) {
    if (rate <= 0) {
      throw FinanceException('invalid_rate', 'Tỷ giá phải lớn hơn 0');
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

  void addIncome({
    required String requestId,
    required String walletId,
    required int amountMinor,
    required String date,
    String? categoryId,
    String? note,
  }) {
    core.addIncome(
        requestId: requestId,
        walletId: walletId,
        amountMinor: amountMinor,
        date: date,
        categoryId: categoryId,
        note: note);
    notifyListeners();
  }

  void addExpense({
    required String requestId,
    required String walletId,
    required int amountMinor,
    required String date,
    String? categoryId,
    String? note,
  }) {
    core.addExpense(
        requestId: requestId,
        walletId: walletId,
        amountMinor: amountMinor,
        date: date,
        categoryId: categoryId,
        note: note);
    notifyListeners();
  }

  void transfer({
    required String requestId,
    required String fromWalletId,
    required String toWalletId,
    required int amountMinor,
    required String date,
    int? destinationAmountMinor,
    String? note,
  }) {
    core.transfer(
        requestId: requestId,
        fromWalletId: fromWalletId,
        toWalletId: toWalletId,
        amountMinor: amountMinor,
        destinationAmountMinor: destinationAmountMinor,
        date: date,
        note: note);
    notifyListeners();
  }

  void deleteTransaction(String transactionId) {
    core.deleteTransaction(transactionId);
    notifyListeners();
  }

  void restoreTransaction(String transactionId) {
    core.restoreTransaction(transactionId);
    notifyListeners();
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

  int streak(DateTime today) => savings.currentStreak(dateKey(today));

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
    return 'Ví không đủ tiền, còn thiếu '
        '${formatMinor(error.shortfallMinor, error.currency ?? 'VND')}.';
  }
  if (error is FinanceException) return error.message;
  return 'Có lỗi xảy ra, chưa có gì được lưu.';
}

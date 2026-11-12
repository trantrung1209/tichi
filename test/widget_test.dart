import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tichi/app/seed.dart';
import 'package:tichi/app/store.dart';
import 'package:tichi/app/theme.dart';
import 'package:tichi/core/finance/finance_core.dart';
import 'package:tichi/main.dart';
import 'package:tichi/ui/savings_screen.dart';

void main() {
  late FinanceCore core;
  late AppStore store;

  Future<void> openApp(WidgetTester tester,
      {void Function(AppStore store)? data, bool firstLaunch = false}) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    core = FinanceCore.inMemory();
    seedIfEmpty(core);
    if (!firstLaunch) core.setSetting('onboarding_done', '1');
    store = AppStore(core);
    addTearDown(() => TichiColors.dark = false);
    data?.call(store);
    await tester.pumpWidget(TichiApp(store: store));
    await tester.pumpAndSettle();
  }

  Future<void> addTransaction(WidgetTester tester,
      {required String type, required String amount}) async {
    await tester.tap(find.byTooltip('Thêm giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('type-$type')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), amount);
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, IconData icon) async {
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.byIcon(icon)));
    await tester.pumpAndSettle();
  }

  String totalAssets(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('total-assets'))).data!;

  tearDown(() => core.close());

  testWidgets('lần đầu mở app: đi hết hướng dẫn, nhập số dư, vào Trang chủ',
      (tester) async {
    await openApp(tester, firstLaunch: true);
    expect(find.text('Chào mừng đến Tichi'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Bạn đang có bao nhiêu?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('opening-Tiền mặt')), '300000');
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(totalAssets(tester), '300.000 ₫');
    expect(store.onboardingDone, isTrue);
    expect(store.reminderEnabled, isTrue);
  });

  testWidgets('mở app lần sau vào thẳng Tổng quan với số dư 0', (tester) async {
    await openApp(tester);
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(totalAssets(tester), '0 ₫');
  });

  testWidgets('ô số tiền tự thêm dấu chấm khi gõ', (tester) async {
    await openApp(tester);
    await tester.tap(find.byTooltip('Thêm giao dịch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '1000000');
    await tester.pump();
    expect(find.text('1.000.000'), findsOneWidget);
  });

  testWidgets('đổi sang giao diện tối rồi về sáng', (tester) async {
    await openApp(tester);
    await openTab(tester, Icons.more_horiz);
    ThemeData theme() => Theme.of(tester.element(find.byType(NavigationBar)));
    int tab() =>
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

    await tester.ensureVisible(find.text('Tối'));
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();
    expect(store.themeMode, 'dark');
    expect(TichiColors.dark, isTrue);
    expect(theme().brightness, Brightness.dark);
    expect(theme().scaffoldBackgroundColor, const Color(0xFF111413));
    expect(tab(), 4, reason: 'đổi giao diện không được đưa về tab khác');
    expect(find.text('Sáng'), findsOneWidget,
        reason: 'mục Thêm vẫn phải đang hiện sau khi đổi giao diện');

    await tester.tap(find.text('Sáng'));
    await tester.pumpAndSettle();
    expect(store.themeMode, 'light');
    expect(TichiColors.dark, isFalse);
    expect(theme().brightness, Brightness.light);
  });

  testWidgets('ghi khoản thu thì Trang chủ cập nhật', (tester) async {
    await openApp(tester);
    await addTransaction(tester, type: 'INCOME', amount: '500000');
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(totalAssets(tester), '500.000 ₫');
    expect(find.text('+500.000 ₫'), findsWidgets);
  });

  testWidgets('chi vượt số dư thì ví âm, vẫn lưu được', (tester) async {
    await openApp(tester);
    await addTransaction(tester, type: 'EXPENSE', amount: '55000');
    expect(find.byKey(const Key('form-error')), findsNothing);
    expect(totalAssets(tester), '−55.000 ₫');
    expect(core.activeTransactionCount(), 1);
  });

  testWidgets('các mục Ngân sách, Tiết kiệm, Thêm mở được với dữ liệu thật',
      (tester) async {
    late String goalId;
    await openApp(tester, data: (store) {
      final bank = store.spendingWallets()[1];
      final vault = store.savingsWallets().first;
      final food = store.categories('EXPENSE').first;
      store.addIncome(
          requestId: 'salary',
          walletId: bank.id,
          amountMinor: 20000000,
          date: '2026-11-01');
      store.addExpense(
          requestId: 'lunch',
          walletId: bank.id,
          amountMinor: 2500000,
          date: '2026-11-02',
          categoryId: food.id);
      goalId = store.createGoal(
          name: 'Du lịch',
          targetMinor: 30000000,
          savingsWalletId: vault.id,
          startDate: '2026-11-01',
          targetDate: '2099-12-31',
          priority: 1,
          icon: 'travel');
      store.contribute(
          requestId: 'first',
          goalId: goalId,
          fromWalletId: bank.id,
          amountMinor: 1000000,
          date: '2026-11-03');
      store.setBudget(amountMinor: 10000000);
      store.setBudget(categoryId: food.id, amountMinor: 3000000);
    });

    await openTab(tester, Icons.pie_chart_outline);
    expect(find.text('Còn lại trong tháng'), findsOneWidget);
    expect(find.text('Theo danh mục'), findsOneWidget);

    await openTab(tester, Icons.savings_outlined);
    expect(find.text('Mục tiêu của bạn'), findsOneWidget);
    // Trang chủ (đang ẩn phía sau) cũng có thẻ "Du lịch", nên chỉ tìm trong
    // màn hình Tiết kiệm.
    final goalCard = find.descendant(
        of: find.byType(SavingsScreen), matching: find.text('Du lịch'));
    await tester.ensureVisible(goalCard);
    await tester.tap(goalCard);
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử'), findsOneWidget);

    await tester.tap(find.text('Tiết kiệm ngay'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('move-amount')), '200000');
    await tester.tap(find.byKey(const Key('move-confirm')));
    await tester.pumpAndSettle();
    expect(store.goal(goalId).savedMinor, 1200000);

    // App dùng tiếng Việt nên nút quay lại không có chữ 'Back';
    // tìm thẳng nút BackButton.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await openTab(tester, Icons.more_horiz);
    await tester.tap(find.text('Ví'));
    await tester.pumpAndSettle();
    expect(find.text('Ví chi tiêu'), findsOneWidget);
    expect(find.text('Ví tiết kiệm'), findsWidgets);
  });
}

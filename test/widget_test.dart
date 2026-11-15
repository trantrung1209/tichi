import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tichi/app/seed.dart';
import 'package:tichi/app/store.dart';
import 'package:tichi/app/theme.dart';
import 'package:tichi/core/finance/finance_core.dart';
import 'package:tichi/core/l10n.dart';
import 'package:tichi/main.dart';
import 'package:tichi/ui/about_screen.dart';
import 'package:tichi/ui/more_screen.dart';
import 'package:tichi/ui/savings_screen.dart';
import 'package:tichi/ui/transactions_screen.dart';
import 'package:tichi/ui/widgets.dart';

void main() {
  late FinanceCore core;
  late AppStore store;

  Future<void> openApp(WidgetTester tester,
      {void Function(AppStore store)? data, bool firstLaunch = false}) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    core = FinanceCore.inMemory();
    seedIfEmpty(core);
    // Máy chạy kiểm thử để tiếng Anh; các bài dưới đây kiểm tra chữ tiếng Việt.
    core.setSetting('language', 'vi');
    if (!firstLaunch) {
      core.setSetting('onboarding_done', '1');
      core.setSetting('user_name', 'Trung');
    }
    store = AppStore(core);
    addTearDown(() {
      TichiColors.dark = false;
      L10n.en = false;
    });
    data?.call(store);
    await tester.pumpWidget(TichiApp(store: store));
    await tester.pumpAndSettle();
  }

  /// Cuộn danh sách ở mục Thêm tới khi thấy [finder]: các dòng ở xa phía
  /// dưới chưa được dựng ra nếu chưa cuộn tới.
  Future<void> scrollInMore(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300,
        scrollable: find
            .descendant(
                of: find.byType(MoreScreen), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
  }

  Future<void> enterName(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const Key('name-field')), name);
    await tester.tap(find.byKey(const Key('name-start')));
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
    await enterName(tester, 'Shin');
    expect(find.text('Chào mừng đến Tichi'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Bạn đang có bao nhiêu?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('opening-Tiền mặt')), '300000');
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-greeting')), findsOneWidget);
    expect(totalAssets(tester), '300.000 ₫');
    expect(store.onboardingDone, isTrue);
    expect(store.reminderEnabled, isTrue);
  });

  testWidgets('mở app lần sau vào thẳng Tổng quan với số dư 0', (tester) async {
    await openApp(tester);
    expect(find.byKey(const Key('home-greeting')), findsOneWidget);
    expect(totalAssets(tester), '0 ₫');
  });

  testWidgets('màn chào mừng có nút khôi phục bản sao lưu', (tester) async {
    await openApp(tester, firstLaunch: true);
    await enterName(tester, 'Shin');
    expect(find.byKey(const Key('onboarding-restore')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-restore')), findsNothing);
  });

  testWidgets('nhắc sao lưu sau vài ngày dùng, bấm Để sau thì ẩn',
      (tester) async {
    await openApp(tester, data: (store) {
      store.addIncome(
          requestId: 'first',
          walletId: store.spendingWallets().first.id,
          amountMinor: 100000,
          date: '2026-11-01');
      final fiveDaysAgo = DateTime.now()
          .subtract(const Duration(days: 5))
          .toUtc()
          .millisecondsSinceEpoch;
      store.core.db
          .execute('UPDATE transactions SET created_at = ?', [fiveDaysAgo]);
    });
    expect(find.byKey(const Key('backup-banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-later')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-banner')), findsNothing);
    expect(store.backupDue(DateTime.now()), isFalse);
    expect(store.backupDue(DateTime.now().add(const Duration(days: 8))),
        isTrue);

    store.markBackedUp(DateTime.now());
    expect(store.backupDue(DateTime.now().add(const Duration(days: 8))),
        isFalse);
    expect(store.backupDue(DateTime.now().add(const Duration(days: 15))),
        isTrue);
  });

  testWidgets('mới dùng thì chưa nhắc sao lưu', (tester) async {
    await openApp(tester);
    await addTransaction(tester, type: 'EXPENSE', amount: '55000');
    expect(find.byKey(const Key('backup-banner')), findsNothing);
  });

  testWidgets('hỏi tên lần đầu: không nhận tên rỗng, bỏ khoảng trắng thừa',
      (tester) async {
    await openApp(tester, firstLaunch: true);
    expect(find.text('Chào bạn! Tichi có thể gọi bạn là gì?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name-field')), '    ');
    await tester.tap(find.byKey(const Key('name-start')));
    await tester.pumpAndSettle();
    expect(store.userName, isNull);
    expect(find.text('Hãy nhập tên gọi của bạn'), findsOneWidget);

    await enterName(tester, '  Shin   Nguyen  ');
    expect(store.userName, 'Shin Nguyen');
    expect(find.text('Chào mừng đến Tichi'), findsOneWidget);
  });

  testWidgets('người dùng cũ chưa có tên thì được hỏi tên một lần',
      (tester) async {
    await openApp(tester, data: (store) {
      store.core.setSetting('user_name', '');
    });
    expect(find.byKey(const Key('name-field')), findsOneWidget);
    await enterName(tester, 'Trung');
    expect(find.byKey(const Key('home-greeting')), findsOneWidget);
    expect(find.text('Xin chào, Trung 👋'), findsOneWidget);
  });

  testWidgets('đổi tên ở mục Thêm thì lời chào cập nhật ngay', (tester) async {
    await openApp(tester);
    expect(find.text('Xin chào, Trung 👋'), findsOneWidget);
    await openTab(tester, Icons.more_horiz);
    await tester.tap(find.byKey(const Key('edit-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('edit-name-field')), 'Một cái tên rất rất dài');
    await tester.tap(find.byKey(const Key('edit-name-save')));
    await tester.pumpAndSettle();
    expect(store.userName, 'Một cái tên rất rất dài');
    await openTab(tester, Icons.home_outlined);
    expect(find.text('Xin chào, Một cái tên rất rất dài 👋'), findsOneWidget);
  });

  testWidgets('trang Giới thiệu về Tichi mở được và có tên tác giả',
      (tester) async {
    await openApp(tester);
    await openTab(tester, Icons.more_horiz);
    // Mục này nằm cuối danh sách, phải cuộn xuống thì mới được dựng ra.
    await tester.scrollUntilVisible(find.text('Giới thiệu về Tichi'), 300,
        scrollable: find
            .descendant(
                of: find.byType(MoreScreen), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giới thiệu về Tichi'));
    await tester.pumpAndSettle();
    expect(find.text('Tichi có gì'), findsOneWidget);
    expect(find.text('Ngân sách'), findsWidgets);
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AboutScreen),
            matching: find.textContaining('Trung Nguyen')),
        findsOneWidget);
  });

  testWidgets('nhấn quay lại: tab khác về Trang chủ, Trang chủ báo nhấn lần nữa',
      (tester) async {
    await openApp(tester);
    await openTab(tester, Icons.pie_chart_outline);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Nhấn quay lại lần nữa để thoát Tichi'), findsOneWidget);
  });

  testWidgets('chạm vào giao dịch để sửa số tiền', (tester) async {
    await openApp(tester);
    await addTransaction(tester, type: 'INCOME', amount: '500000');
    await openTab(tester, Icons.receipt_long_outlined);
    await tester.tap(find.descendant(
        of: find.byType(TransactionsScreen),
        matching: find.text('+500.000 ₫')).last);
    await tester.pumpAndSettle();
    expect(find.text('Sửa giao dịch'), findsOneWidget);
    expect(find.text('500.000'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('amount-field')), '750000');
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    expect(core.activeTransactionCount(), 1);
    expect(store.homeSummary(DateTime.now()).totalMinor, 750000);
  });

  testWidgets('ô USD: gõ dấu phẩy được hiểu là dấu thập phân', (tester) async {
    final formatter = MoneyInputFormatter('USD');
    TextEditingValue type(String old, String next) =>
        formatter.formatEditUpdate(
            TextEditingValue(
                text: old,
                selection: TextSelection.collapsed(offset: old.length)),
            TextEditingValue(
                text: next,
                selection: TextSelection.collapsed(offset: next.length)));
    expect(type('12', '12,').text, '12.');
    expect(type('12.5', '12.5,').text, '12.5');
    expect(type('1,234', '1,2345').text, '12,345');
  });

  testWidgets('đổi sang tiếng Anh rồi về tiếng Việt, chữ đổi ngay',
      (tester) async {
    await openApp(tester);
    await openTab(tester, Icons.more_horiz);
    await scrollInMore(tester, find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(store.language, 'en');
    expect(L10n.en, isTrue);
    expect(find.text('Appearance', skipOffstage: false), findsOneWidget);
    expect(find.text('Language', skipOffstage: false), findsOneWidget);
    await openTab(tester, Icons.home_outlined);
    expect(find.text('Hello, Trung 👋'), findsOneWidget);
    expect(find.text('Total balance'), findsOneWidget);

    await openTab(tester, Icons.more_horiz);
    await scrollInMore(tester, find.text('Tiếng Việt'));
    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();
    expect(L10n.en, isFalse);
    expect(find.text('Giao diện', skipOffstage: false), findsOneWidget);
  });

  testWidgets('cài mới trên máy tiếng Anh: ví, danh mục và chữ bằng tiếng Anh',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => L10n.en = false);
    core = FinanceCore.inMemory();
    seedIfEmpty(core, english: true, currency: 'USD');
    store = AppStore(core);
    await tester.pumpWidget(TichiApp(store: store));
    await tester.pumpAndSettle();
    expect(L10n.en, isTrue);
    expect(find.text('Hi there! What should Tichi call you?'), findsOneWidget);
    expect(store.spendingWallets().first.name, 'Cash');
    expect(store.baseCurrency, 'USD');
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

    await scrollInMore(tester, find.text('Tối'));
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
    expect(find.byKey(const Key('home-greeting')), findsOneWidget);
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

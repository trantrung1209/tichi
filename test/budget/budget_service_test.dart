import 'package:flutter_test/flutter_test.dart';
import 'package:tichi/core/budget/budget_service.dart';
import 'package:tichi/core/finance/finance_core.dart';
import 'package:tichi/core/savings/savings_center.dart';

Matcher throwsFinance(String code) => throwsA(
    isA<FinanceException>().having((e) => e.code, 'code', code));

void main() {
  late FinanceCore core;
  late BudgetService budgets;
  late String bank;
  late String usd;
  late String vault;
  late String food;
  late String fun;
  late String salary;
  var counter = 0;
  String req() => 'req-${counter++}';

  setUp(() {
    core = FinanceCore.inMemory();
    budgets = BudgetService(core);
    bank = core.createWallet(
        name: 'Ngân hàng',
        type: 'BANK',
        currencyCode: 'VND',
        openingBalanceMinor: 50000000);
    usd = core.createWallet(
        name: 'USD', type: 'BANK', currencyCode: 'USD');
    vault = core.createWallet(
        name: 'Ví tiết kiệm', type: 'SAVINGS', currencyCode: 'VND');
    food = core.createCategory(
        name: 'Ăn uống', type: 'EXPENSE', icon: 'food', color: 'orange');
    fun = core.createCategory(name: 'Giải trí', type: 'EXPENSE');
    salary = core.createCategory(name: 'Lương', type: 'INCOME');
  });

  tearDown(() => core.close());

  void spend(String category, int amount, String date, {String? wallet}) {
    core.addExpense(
        requestId: req(),
        walletId: wallet ?? bank,
        amountMinor: amount,
        date: date,
        categoryId: category);
  }

  test('ngân sách tổng trước, rồi tới danh mục; số đã dùng đúng', () {
    budgets.setBudget(
        categoryId: food, currencyCode: 'VND', amountMinor: 4000000);
    budgets.setBudget(currencyCode: 'VND', amountMinor: 12000000);
    spend(food, 3000000, '2026-11-02');
    spend(fun, 500000, '2026-11-05');

    final list = budgets.statuses(year: 2026, month: 11, currencyCode: 'VND');
    expect(list.map((b) => b.name), ['Cả tháng', 'Ăn uống']);
    expect(list[0].spentMinor, 3500000);
    expect(list[0].remainingMinor, 8500000);
    expect(list[1].spentMinor, 3000000);
    expect(list[1].percent, 75);
    expect(list[1].level, 'ok');
    expect(list[1].icon, 'food');
  });

  test('không tính tháng khác, giao dịch đã xóa, chuyển ví, tiết kiệm, '
      'ví khác loại tiền', () {
    budgets.setBudget(currencyCode: 'VND', amountMinor: 10000000);
    spend(food, 999, '2026-10-31');
    final deleted = core.addExpense(
        requestId: req(),
        walletId: bank,
        amountMinor: 111,
        date: '2026-11-06',
        categoryId: food);
    core.deleteTransaction(deleted);
    final savings = SavingsCenter(core);
    final goal = savings.createGoal(
        name: 'Du lịch',
        targetMinor: 5000000,
        savingsWalletId: vault,
        startDate: '2026-11-01',
        targetDate: '2027-01-01');
    savings.contribute(
        requestId: req(),
        goalId: goal,
        fromWalletId: bank,
        amountMinor: 2000000,
        date: '2026-11-07');
    core.addIncome(
        requestId: req(),
        walletId: usd,
        amountMinor: 100000,
        date: '2026-11-01',
        categoryId: salary);
    spend(food, 5000, '2026-11-08', wallet: usd);

    final overall =
        budgets.statuses(year: 2026, month: 11, currencyCode: 'VND').single;
    expect(overall.spentMinor, 0);
  });

  test('mức cảnh báo 80% và vượt 100%', () {
    budgets.setBudget(
        categoryId: food, currencyCode: 'VND', amountMinor: 1000000);
    spend(food, 800000, '2026-11-02');
    expect(
        budgets
            .statuses(year: 2026, month: 11, currencyCode: 'VND')
            .single
            .level,
        'warning');
    spend(food, 300000, '2026-11-03');
    final status =
        budgets.statuses(year: 2026, month: 11, currencyCode: 'VND').single;
    expect(status.level, 'over');
    expect(status.percent, 110);
    expect(status.remainingMinor, -100000);
  });

  test('đặt lại thì sửa số, không tạo trùng; xóa thì biến mất', () {
    final first = budgets.setBudget(
        categoryId: food, currencyCode: 'VND', amountMinor: 1000000);
    final second = budgets.setBudget(
        categoryId: food, currencyCode: 'VND', amountMinor: 2000000);
    expect(second, first);
    final list = budgets.statuses(year: 2026, month: 11, currencyCode: 'VND');
    expect(list.single.limitMinor, 2000000);
    budgets.deleteBudget(first);
    expect(budgets.statuses(year: 2026, month: 11, currencyCode: 'VND'),
        isEmpty);
    budgets.setBudget(
        categoryId: food, currencyCode: 'VND', amountMinor: 3000000);
    expect(
        budgets
            .statuses(year: 2026, month: 11, currencyCode: 'VND')
            .single
            .limitMinor,
        3000000);
  });

  test('chỉ đặt cho danh mục chi và số tiền dương', () {
    expect(
        () => budgets.setBudget(
            categoryId: salary, currencyCode: 'VND', amountMinor: 1000),
        throwsFinance('not_expense_category'));
    expect(() => budgets.setBudget(currencyCode: 'VND', amountMinor: 0),
        throwsFinance('invalid_amount'));
  });

  test('tính đúng tháng 28, 29, 30, 31 ngày; không lẫn tháng bên cạnh', () {
    budgets.setBudget(
        categoryId: food, currencyCode: 'VND', amountMinor: 10000000);
    // Năm thường: tháng 2 có 28 ngày.
    spend(food, 100, '2027-01-31');
    spend(food, 200, '2027-02-01');
    spend(food, 300, '2027-02-28');
    spend(food, 400, '2027-03-01');
    // Năm nhuận: tháng 2 có 29 ngày.
    spend(food, 1000, '2028-02-29');
    spend(food, 2000, '2028-03-01');
    // Tháng 30 và 31 ngày.
    spend(food, 50, '2026-04-30');
    spend(food, 70, '2026-05-31');
    int spent(int y, int m) => budgets
        .statuses(year: y, month: m, currencyCode: 'VND')
        .firstWhere((s) => s.categoryId == food)
        .spentMinor;
    expect(spent(2027, 1), 100);
    expect(spent(2027, 2), 500);
    expect(spent(2027, 3), 400);
    expect(spent(2028, 2), 1000);
    expect(spent(2028, 3), 2000);
    expect(spent(2026, 4), 50);
    expect(spent(2026, 5), 70);
  });

  test('sửa khoản chi sang tháng khác thì ngân sách tính lại', () {
    budgets.setBudget(
        categoryId: food, currencyCode: 'VND', amountMinor: 1000000);
    final id = core.addExpense(
        requestId: req(),
        walletId: bank,
        amountMinor: 300000,
        date: '2026-11-05',
        categoryId: food);
    core.updateTransaction(id,
        walletId: bank,
        amountMinor: 300000,
        date: '2026-10-05',
        categoryId: food);
    int spent(int m) => budgets
        .statuses(year: 2026, month: m, currencyCode: 'VND')
        .firstWhere((s) => s.categoryId == food)
        .spentMinor;
    expect(spent(11), 0);
    expect(spent(10), 300000);
  });
}

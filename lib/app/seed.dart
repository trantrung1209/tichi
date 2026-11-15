/// Dữ liệu mặc định cho lần mở app đầu tiên.
library;

import '../core/finance/finance_core.dart';

/// (tên tiếng Việt, tên tiếng Anh, biểu tượng, màu)
const _expenseCategories = [
  ('Ăn uống', 'Food & drinks', 'food', 'orange'),
  ('Di chuyển', 'Transport', 'transport', 'blue'),
  ('Mua sắm', 'Shopping', 'shopping', 'pink'),
  ('Nhà ở', 'Housing', 'home', 'teal'),
  ('Hóa đơn', 'Bills', 'bills', 'purple'),
  ('Sức khỏe', 'Health', 'health', 'red'),
  ('Giải trí', 'Entertainment', 'entertainment', 'gold'),
  ('Khác', 'Other', 'more', 'stone'),
];

const _incomeCategories = [
  ('Lương', 'Salary', 'salary', 'green'),
  ('Thưởng', 'Bonus', 'bonus', 'gold'),
  ('Kinh doanh', 'Business', 'business', 'blue'),
  ('Khác', 'Other', 'more', 'stone'),
];

/// Tạo ví và danh mục mặc định nếu cơ sở dữ liệu chưa có ví nào. Số dư đầu
/// là 0; người dùng sửa số dư đầu khi tạo ví mới, hoặc ghi khoản thu.
///
/// [english]: tên ví và danh mục bằng tiếng Anh. [currency]: loại tiền của
/// các ví mặc định và loại tiền hiển thị (VND hoặc USD).
void seedIfEmpty(FinanceCore core,
    {bool english = false, String currency = 'VND'}) {
  if (core.wallets(includeArchived: true).isNotEmpty) return;
  String name(String vi, String en) => english ? en : vi;
  core.runInTransaction(() {
    core.createWallet(
        name: name('Tiền mặt', 'Cash'), type: 'CASH', currencyCode: currency);
    core.createWallet(
        name: name('Ngân hàng', 'Bank'), type: 'BANK', currencyCode: currency);
    core.createWallet(
        name: name('Ví tiết kiệm', 'Savings'),
        type: 'SAVINGS',
        currencyCode: currency);
    for (final (vi, en, icon, color) in _expenseCategories) {
      core.createCategory(
          name: name(vi, en), type: 'EXPENSE', icon: icon, color: color);
    }
    for (final (vi, en, icon, color) in _incomeCategories) {
      core.createCategory(
          name: name(vi, en), type: 'INCOME', icon: icon, color: color);
    }
    core.setSetting('base_currency', currency);
  });
}

/// Dữ liệu mặc định cho lần mở app đầu tiên.
library;

import '../core/finance/finance_core.dart';

/// (tên, biểu tượng, màu)
const _expenseCategories = [
  ('Ăn uống', 'food', 'orange'),
  ('Di chuyển', 'transport', 'blue'),
  ('Mua sắm', 'shopping', 'pink'),
  ('Nhà ở', 'home', 'teal'),
  ('Hóa đơn', 'bills', 'purple'),
  ('Sức khỏe', 'health', 'red'),
  ('Giải trí', 'entertainment', 'gold'),
  ('Khác', 'more', 'stone'),
];

const _incomeCategories = [
  ('Lương', 'salary', 'green'),
  ('Thưởng', 'bonus', 'gold'),
  ('Kinh doanh', 'business', 'blue'),
  ('Khác', 'more', 'stone'),
];

/// Tạo ví và danh mục mặc định nếu cơ sở dữ liệu chưa có ví nào. Số dư đầu
/// là 0; người dùng sửa số dư đầu khi tạo ví mới, hoặc ghi khoản thu.
void seedIfEmpty(FinanceCore core) {
  if (core.wallets(includeArchived: true).isNotEmpty) return;
  core.runInTransaction(() {
    core.createWallet(name: 'Tiền mặt', type: 'CASH', currencyCode: 'VND');
    core.createWallet(name: 'Ngân hàng', type: 'BANK', currencyCode: 'VND');
    core.createWallet(
        name: 'Ví tiết kiệm', type: 'SAVINGS', currencyCode: 'VND');
    for (final (name, icon, color) in _expenseCategories) {
      core.createCategory(name: name, type: 'EXPENSE', icon: icon, color: color);
    }
    for (final (name, icon, color) in _incomeCategories) {
      core.createCategory(name: name, type: 'INCOME', icon: icon, color: color);
    }
    core.setSetting('base_currency', 'VND');
  });
}

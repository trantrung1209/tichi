/// Tichi – ngân sách theo tháng.
///
/// - Một ngân sách tổng cho cả tháng và một ngân sách riêng cho từng danh mục
///   chi, mỗi cái gắn với một loại tiền.
/// - Số đã dùng = các khoản chi (không gồm chuyển ví, không gồm tiết kiệm)
///   trong tháng, từ ví cùng loại tiền, chưa bị xóa.
/// - Mức cảnh báo: từ 80% là "sắp chạm", từ 100% là "vượt".
library;

import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../finance/finance_core.dart';

class BudgetStatus {
  const BudgetStatus({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.currencyCode,
    required this.limitMinor,
    required this.spentMinor,
  });

  final String id;

  /// Null là ngân sách tổng cả tháng.
  final String? categoryId;
  final String name;
  final String icon;
  final String color;
  final String currencyCode;
  final int limitMinor;
  final int spentMinor;

  bool get isOverall => categoryId == null;

  /// Còn lại; âm khi đã vượt.
  int get remainingMinor => limitMinor - spentMinor;

  /// Phần trăm đã dùng, làm tròn xuống, có thể trên 100.
  int get percent => spentMinor * 100 ~/ limitMinor;

  /// ok, warning (từ 80%) hoặc over (từ 100%).
  String get level => percent >= 100
      ? 'over'
      : percent >= 80
          ? 'warning'
          : 'ok';
}

class BudgetService {
  BudgetService(this._core);

  final FinanceCore _core;
  final Random _random = Random.secure();

  Database get _db => _core.db;

  /// Đặt hoặc sửa ngân sách. [categoryId] null là ngân sách tổng. Trả về mã
  /// ngân sách.
  String setBudget({
    String? categoryId,
    required String currencyCode,
    required int amountMinor,
  }) {
    if (amountMinor <= 0) {
      throw FinanceException('invalid_amount', 'Ngân sách phải lớn hơn 0');
    }
    return _core.runInTransaction(() {
      if (categoryId != null) {
        final rows = _db.select(
            'SELECT type FROM categories WHERE id = ?', [categoryId]);
        if (rows.isEmpty) {
          throw FinanceException(
              'category_not_found', 'Không tìm thấy danh mục');
        }
        if (rows.first['type'] != 'EXPENSE') {
          throw FinanceException(
              'not_expense_category', 'Ngân sách chỉ dành cho danh mục chi');
        }
      }
      final existing = _find(categoryId, currencyCode);
      final now = _now();
      if (existing != null) {
        _db.execute(
            'UPDATE budgets SET amount_minor = ?, updated_at = ? WHERE id = ?',
            [amountMinor, now, existing]);
        return existing;
      }
      final id = _newId();
      _db.execute(
        'INSERT INTO budgets (id, category_id, currency_code, amount_minor, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [id, categoryId, currencyCode, amountMinor, now, now],
      );
      return id;
    });
  }

  void deleteBudget(String budgetId) {
    _db.execute(
        'UPDATE budgets SET deleted_at = ? WHERE id = ? AND deleted_at IS NULL',
        [_now(), budgetId]);
  }

  /// Tình trạng các ngân sách của một loại tiền trong tháng: ngân sách tổng
  /// trước, rồi tới các danh mục theo thứ tự đặt.
  List<BudgetStatus> statuses({
    required int year,
    required int month,
    required String currencyCode,
  }) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-%';
    final rows = _db.select(
      'SELECT b.id, b.category_id, b.amount_minor, b.currency_code, '
      'c.name AS category_name, c.icon AS category_icon, '
      'c.color AS category_color, '
      '(SELECT COALESCE(SUM(t.amount_minor), 0) FROM transactions t '
      ' JOIN wallets w ON w.id = t.source_wallet_id '
      " WHERE t.type = 'EXPENSE' AND t.deleted_at IS NULL "
      ' AND w.currency_code = b.currency_code '
      ' AND t.transaction_date LIKE ?1 '
      ' AND (b.category_id IS NULL OR t.category_id = b.category_id)) AS spent '
      'FROM budgets b LEFT JOIN categories c ON c.id = b.category_id '
      'WHERE b.deleted_at IS NULL AND b.currency_code = ?2 '
      'ORDER BY (b.category_id IS NOT NULL), b.created_at, b.rowid',
      [prefix, currencyCode],
    );
    return [
      for (final row in rows)
        BudgetStatus(
          id: row['id'] as String,
          categoryId: row['category_id'] as String?,
          name: (row['category_name'] as String?) ?? 'Cả tháng',
          icon: (row['category_icon'] as String?) ?? 'budget',
          color: (row['category_color'] as String?) ?? 'emerald',
          currencyCode: row['currency_code'] as String,
          limitMinor: row['amount_minor'] as int,
          spentMinor: row['spent'] as int,
        ),
    ];
  }

  String? _find(String? categoryId, String currencyCode) {
    final rows = categoryId == null
        ? _db.select(
            'SELECT id FROM budgets WHERE deleted_at IS NULL '
            'AND category_id IS NULL AND currency_code = ?',
            [currencyCode])
        : _db.select(
            'SELECT id FROM budgets WHERE deleted_at IS NULL '
            'AND category_id = ? AND currency_code = ?',
            [categoryId, currencyCode]);
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  String _newId() {
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

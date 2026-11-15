/// Tichi – Finance Core: nơi duy nhất được phép thay đổi dữ liệu tài chính.
///
/// Giao diện không tự sửa số dư. Mọi thao tác thu, chi, chuyển ví đều đi qua
/// lớp này, chạy trong một transaction của SQLite: hoặc ghi trọn vẹn, hoặc
/// không ghi gì.
///
/// Quy tắc số dư:
/// - Ví thường (tiền mặt, ngân hàng, ví điện tử) được phép âm.
/// - Ví tiết kiệm không bao giờ âm. Tiền chỉ vào ví tiết kiệm từ ví nguồn có
///   đủ số dư, để không tạo ra tiền tiết kiệm "ảo".
library;

import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

/// Số tiền lớn nhất cho một giao dịch, theo đơn vị nhỏ nhất (100.000 tỷ đồng
/// hoặc 1.000 tỷ USD). Giới hạn này giữ cho các phép cộng không bị tràn số.
const int maxAmountMinor = 100000000000000;

/// Lỗi nghiệp vụ. [code] dùng để giao diện chọn thông báo phù hợp.
class FinanceException implements Exception {
  FinanceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'FinanceException($code): $message';
}

/// Ví nguồn không đủ tiền. [shortfallMinor] là số tiền còn thiếu.
class InsufficientFundsException extends FinanceException {
  InsufficientFundsException(this.balanceMinor, this.shortfallMinor,
      {this.currency})
      : super('insufficient_funds',
            'Số dư $balanceMinor, còn thiếu $shortfallMinor');

  final int balanceMinor;
  final int shortfallMinor;

  /// Loại tiền của ví thiếu tiền.
  final String? currency;
}

const List<String> walletTypes = ['CASH', 'BANK', 'EWALLET', 'SAVINGS'];

class WalletInfo {
  const WalletInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.balanceMinor,
    required this.isArchived,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String type;
  final String currencyCode;
  final int balanceMinor;
  final bool isArchived;
  final String icon;
  final String color;

  bool get isSavings => type == 'SAVINGS';
}

class CategoryInfo {
  const CategoryInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isArchived,
  });

  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final bool isArchived;
}

/// Một giao dịch kèm tên ví và danh mục, để hiển thị.
class TransactionView {
  const TransactionView({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.destinationAmountMinor,
    required this.date,
    required this.note,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.sourceWalletName,
    required this.sourceCurrency,
    required this.sourceIsSavings,
    required this.destinationWalletName,
    required this.destinationCurrency,
    required this.destinationIsSavings,
    this.sourceWalletId,
    this.destinationWalletId,
    this.categoryId,
  });

  final String id;
  final String type;
  final int amountMinor;
  final int? destinationAmountMinor;
  final String date;
  final String? note;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? sourceWalletName;
  final String? sourceCurrency;
  final bool sourceIsSavings;
  final String? destinationWalletName;
  final String? destinationCurrency;
  final bool destinationIsSavings;
  final String? sourceWalletId;
  final String? destinationWalletId;
  final String? categoryId;

  /// Là lần góp hoặc rút tiết kiệm (chạm vào ví tiết kiệm).
  bool get isSavingsMove => sourceIsSavings || destinationIsSavings;

  /// Loại tiền của [amountMinor].
  String get currency =>
      type == 'INCOME' ? destinationCurrency! : sourceCurrency!;
}

/// Tổng thu và chi của một tháng, theo một loại tiền.
class MonthSummary {
  const MonthSummary({required this.incomeMinor, required this.expenseMinor});

  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

/// Được gọi bên trong transaction mỗi khi số dư của các ví thay đổi ngoài
/// luồng thu, chi, chuyển thông thường (xóa hoặc khôi phục giao dịch). Ném
/// lỗi để hủy toàn bộ thao tác.
typedef WalletsChangedListener = void Function(Set<String> walletIds);

class FinanceCore {
  FinanceCore(this._db, {this.debugHook}) {
    _db.execute('PRAGMA foreign_keys = ON');
  }

  /// Mở một cơ sở dữ liệu trong bộ nhớ đã có sẵn bảng. Dùng cho kiểm thử.
  factory FinanceCore.inMemory({void Function(String step)? debugHook}) {
    final core = FinanceCore(sqlite3.openInMemory(), debugHook: debugHook);
    core.migrate();
    return core;
  }

  final Database _db;

  /// Chỉ dành cho các lớp nghiệp vụ cùng gói (Savings Center, ngân sách).
  /// Giao diện không được dùng trực tiếp.
  Database get db => _db;

  /// Chỉ dùng trong kiểm thử: được gọi sau khi ghi và trước khi commit, để
  /// giả lập lỗi giữa chừng.
  final void Function(String step)? debugHook;

  final List<WalletsChangedListener> _listeners = [];
  final Random _random = Random.secure();
  int _transactionDepth = 0;
  int _savepointCounter = 0;

  void addWalletsChangedListener(WalletsChangedListener listener) =>
      _listeners.add(listener);

  /// Nâng cơ sở dữ liệu lên phiên bản mới nhất, từng bước một. Dữ liệu cũ
  /// được giữ nguyên.
  void migrate({int toVersion = schemaVersion}) {
    if (_db.userVersion >= toVersion) return;
    _inTransaction(() {
      var version = _db.userVersion;
      while (version < toVersion) {
        version++;
        final statements = migrations[version];
        if (statements == null) {
          throw StateError('Thiếu bước nâng cấp lên phiên bản $version');
        }
        for (final statement in statements) {
          _db.execute(statement);
        }
        _db.userVersion = version;
      }
    });
  }

  /// Chạy [body] trong một transaction. Gọi lồng nhau thì phần bên trong là
  /// một savepoint: lỗi ở bất kỳ đâu đều hoàn tác toàn bộ thao tác ngoài cùng.
  T runInTransaction<T>(T Function() body) => _inTransaction(body);

  /// Mã giao dịch đã tạo với [requestId], hoặc null nếu chưa có.
  String? transactionIdForRequest(String requestId) =>
      _findByRequestId(requestId);

  void close() => _db.close();

  // ---------------------------------------------------------------- Ví

  String createWallet({
    required String name,
    required String type,
    required String currencyCode,
    int openingBalanceMinor = 0,
    String? icon,
    String? color,
  }) {
    if (!currencyExponent.containsKey(currencyCode)) {
      throw FinanceException(
          'unsupported_currency', 'Chưa hỗ trợ loại tiền $currencyCode');
    }
    if (!walletTypes.contains(type)) {
      throw FinanceException('invalid_wallet_type', 'Loại ví không hợp lệ');
    }
    _requireName(name);
    if (openingBalanceMinor < 0) {
      throw FinanceException('invalid_amount', 'Số dư đầu không được âm');
    }
    final id = _newId();
    _db.execute(
      'INSERT INTO wallets (id, name, type, currency_code, '
      'opening_balance_minor, icon, color, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        name.trim(),
        type,
        currencyCode,
        openingBalanceMinor,
        icon ?? defaultWalletIcon[type],
        color ?? defaultWalletColor[type],
        _now(),
      ],
    );
    return id;
  }

  /// Đổi tên, biểu tượng hoặc màu của ví. Loại ví và loại tiền không đổi
  /// được sau khi tạo, để lịch sử giao dịch luôn đúng.
  void updateWallet(String walletId,
      {String? name, String? icon, String? color}) {
    _walletRow(walletId);
    if (name != null) _requireName(name);
    _db.execute(
      'UPDATE wallets SET name = COALESCE(?, name), icon = COALESCE(?, icon), '
      'color = COALESCE(?, color) WHERE id = ?',
      [name?.trim(), icon, color, walletId],
    );
  }

  /// Sửa số dư ban đầu của ví (số tiền đã có trước khi dùng Tichi). Ví tiết
  /// kiệm không được giảm xuống dưới phần đã gắn cho mục tiêu.
  void setOpeningBalance(String walletId, int amountMinor) {
    if (amountMinor < 0) {
      throw FinanceException('invalid_amount', 'Số dư ban đầu không được âm');
    }
    _inTransaction(() {
      _walletRow(walletId);
      _db.execute('UPDATE wallets SET opening_balance_minor = ? WHERE id = ?',
          [amountMinor, walletId]);
      _requireSavingsNonNegative(walletId);
      for (final listener in _listeners) {
        listener({walletId});
      }
    });
  }

  /// Ví đã được dùng chưa: có giao dịch (kể cả đã xóa, vì vẫn hoàn tác
  /// được) hoặc có mục tiêu tiết kiệm gắn vào.
  bool walletInUse(String walletId) => _db.select(
      'SELECT 1 FROM transactions WHERE source_wallet_id = ?1 '
      'OR destination_wallet_id = ?1 '
      'UNION ALL SELECT 1 FROM savings_goals WHERE savings_wallet_id = ?1 '
      'LIMIT 1',
      [walletId]).isNotEmpty;

  /// Đổi loại tiền của ví chưa dùng, kèm số dư ban đầu theo loại tiền mới.
  /// Ví đã có giao dịch thì không đổi được, để số liệu cũ không bị sai.
  void setWalletCurrency(String walletId, String currencyCode,
      {int openingBalanceMinor = 0}) {
    if (!currencyExponent.containsKey(currencyCode)) {
      throw FinanceException(
          'unsupported_currency', 'Chưa hỗ trợ loại tiền $currencyCode');
    }
    if (openingBalanceMinor < 0) {
      throw FinanceException('invalid_amount', 'Số dư ban đầu không được âm');
    }
    _inTransaction(() {
      _walletRow(walletId);
      if (walletInUse(walletId)) {
        throw FinanceException('wallet_in_use',
            'Ví đã có giao dịch nên không đổi được loại tiền');
      }
      _db.execute(
          'UPDATE wallets SET currency_code = ?, opening_balance_minor = ? '
          'WHERE id = ?',
          [currencyCode, openingBalanceMinor, walletId]);
      for (final listener in _listeners) {
        listener({walletId});
      }
    });
  }

  int openingBalance(String walletId) {
    final rows = _db.select(
        'SELECT opening_balance_minor AS o FROM wallets WHERE id = ?',
        [walletId]);
    if (rows.isEmpty) {
      throw FinanceException('wallet_not_found', 'Không tìm thấy ví');
    }
    return rows.first['o'] as int;
  }

  /// Lưu trữ (ẩn) hoặc mở lại một ví. Ví lưu trữ vẫn giữ lịch sử và số dư
  /// vẫn tính vào tổng tài sản. Ví tiết kiệm còn mục tiêu thì không lưu trữ
  /// được.
  void setWalletArchived(String walletId, bool archived) {
    final wallet = _walletRow(walletId);
    if (archived && wallet['type'] == 'SAVINGS') {
      final goals = _db.select(
          'SELECT COUNT(*) AS c FROM savings_goals '
          'WHERE savings_wallet_id = ? AND deleted_at IS NULL',
          [walletId]);
      if ((goals.first['c'] as int) > 0) {
        throw FinanceException('wallet_has_goals',
            'Ví này còn mục tiêu tiết kiệm. Xóa hoặc chuyển mục tiêu trước.');
      }
    }
    _db.execute('UPDATE wallets SET is_archived = ? WHERE id = ?',
        [archived ? 1 : 0, walletId]);
  }

  /// Số dư hiện tại của ví, theo đơn vị nhỏ nhất của loại tiền ví đó.
  int walletBalance(String walletId) {
    final rows = _db.select(walletBalanceSql, [walletId]);
    if (rows.isEmpty) {
      throw FinanceException('wallet_not_found', 'Không tìm thấy ví');
    }
    return rows.first['balance'] as int;
  }

  /// Tổng tài sản theo từng loại tiền, ví dụ {'VND': 27400000, 'USD': 15000}.
  /// Ví đã lưu trữ vẫn được tính vì tiền trong đó vẫn là của người dùng.
  Map<String, int> totalAssetsByCurrency() {
    final totals = <String, int>{};
    final wallets = _db.select('SELECT id, currency_code FROM wallets');
    for (final wallet in wallets) {
      final currency = wallet['currency_code'] as String;
      final balance = walletBalance(wallet['id'] as String);
      totals[currency] = (totals[currency] ?? 0) + balance;
    }
    return totals;
  }

  List<WalletInfo> wallets({bool includeArchived = false}) {
    final rows = _db.select(
      'SELECT id, name, type, currency_code, is_archived, icon, color '
      'FROM wallets '
      '${includeArchived ? '' : 'WHERE is_archived = 0 '}'
      'ORDER BY created_at, rowid',
    );
    return [
      for (final row in rows)
        WalletInfo(
          id: row['id'] as String,
          name: row['name'] as String,
          type: row['type'] as String,
          currencyCode: row['currency_code'] as String,
          balanceMinor: walletBalance(row['id'] as String),
          isArchived: row['is_archived'] == 1,
          icon: row['icon'] as String,
          color: row['color'] as String,
        ),
    ];
  }

  WalletInfo wallet(String walletId) {
    for (final info in wallets(includeArchived: true)) {
      if (info.id == walletId) return info;
    }
    throw FinanceException('wallet_not_found', 'Không tìm thấy ví');
  }

  // ----------------------------------------------------------- Danh mục

  String createCategory({
    required String name,
    required String type,
    String icon = 'more',
    String color = 'stone',
  }) {
    if (type != 'INCOME' && type != 'EXPENSE') {
      throw FinanceException('invalid_category_type', 'Loại danh mục sai');
    }
    _requireName(name);
    final id = _newId();
    _db.execute(
      'INSERT INTO categories (id, name, type, icon, color, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [id, name.trim(), type, icon, color, _now()],
    );
    return id;
  }

  void updateCategory(String categoryId,
      {String? name, String? icon, String? color}) {
    _categoryRow(categoryId);
    if (name != null) _requireName(name);
    _db.execute(
      'UPDATE categories SET name = COALESCE(?, name), '
      'icon = COALESCE(?, icon), color = COALESCE(?, color) WHERE id = ?',
      [name?.trim(), icon, color, categoryId],
    );
  }

  /// Ẩn hoặc hiện lại danh mục. Giao dịch cũ vẫn giữ tên danh mục.
  void setCategoryArchived(String categoryId, bool archived) {
    _categoryRow(categoryId);
    _db.execute('UPDATE categories SET is_archived = ? WHERE id = ?',
        [archived ? 1 : 0, categoryId]);
  }

  List<CategoryInfo> categories(String type, {bool includeArchived = false}) {
    final rows = _db.select(
      'SELECT id, name, type, icon, color, is_archived FROM categories '
      'WHERE type = ? ${includeArchived ? '' : 'AND is_archived = 0 '}'
      'ORDER BY created_at, rowid',
      [type],
    );
    return [
      for (final row in rows)
        CategoryInfo(
          id: row['id'] as String,
          name: row['name'] as String,
          type: row['type'] as String,
          icon: row['icon'] as String,
          color: row['color'] as String,
          isArchived: row['is_archived'] == 1,
        ),
    ];
  }

  // ---------------------------------------------------- Danh sách giao dịch

  /// Giao dịch chưa bị xóa, mới nhất trước. [monthPrefix] dạng "2026-11".
  List<TransactionView> transactions({String? monthPrefix, int? limit}) {
    final rows = _db.select(
      'SELECT t.id, t.type, t.amount_minor, t.destination_amount_minor, '
      't.transaction_date, t.note, t.source_wallet_id, '
      't.destination_wallet_id, t.category_id, c.name AS category_name, '
      'c.icon AS category_icon, c.color AS category_color, '
      'sw.name AS source_name, sw.currency_code AS source_currency, '
      'sw.type AS source_type, dw.name AS destination_name, '
      'dw.currency_code AS destination_currency, dw.type AS destination_type '
      'FROM transactions t '
      'LEFT JOIN categories c ON c.id = t.category_id '
      'LEFT JOIN wallets sw ON sw.id = t.source_wallet_id '
      'LEFT JOIN wallets dw ON dw.id = t.destination_wallet_id '
      'WHERE t.deleted_at IS NULL '
      "AND (?1 IS NULL OR t.transaction_date LIKE ?1 || '-%') "
      'ORDER BY t.transaction_date DESC, t.created_at DESC '
      'LIMIT ?2',
      [monthPrefix, limit ?? -1],
    );
    return [
      for (final row in rows)
        TransactionView(
          id: row['id'] as String,
          type: row['type'] as String,
          amountMinor: row['amount_minor'] as int,
          destinationAmountMinor: row['destination_amount_minor'] as int?,
          date: row['transaction_date'] as String,
          note: row['note'] as String?,
          categoryName: row['category_name'] as String?,
          categoryIcon: row['category_icon'] as String?,
          categoryColor: row['category_color'] as String?,
          sourceWalletName: row['source_name'] as String?,
          sourceCurrency: row['source_currency'] as String?,
          sourceIsSavings: row['source_type'] == 'SAVINGS',
          destinationWalletName: row['destination_name'] as String?,
          destinationCurrency: row['destination_currency'] as String?,
          destinationIsSavings: row['destination_type'] == 'SAVINGS',
          sourceWalletId: row['source_wallet_id'] as String?,
          destinationWalletId: row['destination_wallet_id'] as String?,
          categoryId: row['category_id'] as String?,
        ),
    ];
  }

  // ------------------------------------------------------------ Cài đặt

  String? getSetting(String key) {
    final rows =
        _db.select('SELECT value FROM app_settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setSetting(String key, String value) {
    _db.execute(
      'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT (key) DO UPDATE SET value = excluded.value, '
      'updated_at = excluded.updated_at',
      [key, value, _now()],
    );
  }

  // ---------------------------------------------------------- Giao dịch

  /// Ghi một khoản thu vào ví. Trả về mã giao dịch.
  ///
  /// [requestId] là mã do giao diện tạo một lần cho mỗi lần bấm Lưu. Gọi lại
  /// với cùng mã sẽ trả về giao dịch cũ, không tạo giao dịch mới.
  String addIncome({
    required String requestId,
    required String walletId,
    required int amountMinor,
    required String date,
    String? categoryId,
    String? note,
  }) {
    return _inTransaction(() {
      final existing = _findByRequestId(requestId);
      if (existing != null) return existing;
      _requirePositive(amountMinor);
      final wallet = _wallet(walletId);
      _requireNotSavings(wallet, 'income_into_savings',
          'Tiền vào ví tiết kiệm phải đi qua chức năng Tiết kiệm');
      final id = _newId();
      _db.execute(
        'INSERT INTO transactions (id, request_id, type, '
        'destination_wallet_id, category_id, amount_minor, '
        "transaction_date, note, created_at) VALUES (?, ?, 'INCOME', ?, ?, ?, ?, ?, ?)",
        [id, requestId, walletId, categoryId, amountMinor, date, note, _now()],
      );
      debugHook?.call('income_inserted');
      return id;
    });
  }

  /// Ghi một khoản chi từ ví thường. Ví được phép âm. Không chi thẳng từ ví
  /// tiết kiệm.
  String addExpense({
    required String requestId,
    required String walletId,
    required int amountMinor,
    required String date,
    String? categoryId,
    String? note,
  }) {
    return _inTransaction(() {
      final existing = _findByRequestId(requestId);
      if (existing != null) return existing;
      _requirePositive(amountMinor);
      final wallet = _wallet(walletId);
      _requireNotSavings(wallet, 'expense_from_savings',
          'Không ghi chi tiêu trực tiếp từ ví tiết kiệm');
      final id = _newId();
      _db.execute(
        'INSERT INTO transactions (id, request_id, type, source_wallet_id, '
        'category_id, amount_minor, transaction_date, note, created_at) '
        "VALUES (?, ?, 'EXPENSE', ?, ?, ?, ?, ?, ?)",
        [id, requestId, walletId, categoryId, amountMinor, date, note, _now()],
      );
      debugHook?.call('expense_inserted');
      return id;
    });
  }

  /// Chuyển tiền giữa hai ví. Không tính là thu hay chi.
  ///
  /// Hai ví khác loại tiền thì phải truyền [destinationAmountMinor]: số tiền
  /// ví nhận được, do người dùng nhập theo tỷ giá thực tế.
  ///
  /// Ví nguồn là ví thường thì được phép âm, trừ khi [requireSufficientFunds]
  /// bật (Tiết kiệm ngay bật để không tạo tiền tiết kiệm ảo). Ví nguồn là ví
  /// tiết kiệm thì luôn phải đủ tiền.
  ///
  /// [allowSavingsSource] và [allowSavingsDestination] chỉ được bật bởi lớp
  /// nghiệp vụ tiết kiệm. Chuyển ví thông thường không chạm vào ví tiết kiệm.
  String transfer({
    required String requestId,
    required String fromWalletId,
    required String toWalletId,
    required int amountMinor,
    required String date,
    int? destinationAmountMinor,
    String? note,
    bool allowSavingsSource = false,
    bool allowSavingsDestination = false,
    bool requireSufficientFunds = false,
  }) {
    return _inTransaction(() {
      final existing = _findByRequestId(requestId);
      if (existing != null) return existing;
      _requirePositive(amountMinor);
      if (fromWalletId == toWalletId) {
        throw FinanceException(
            'same_wallet', 'Ví nguồn và ví nhận phải khác nhau');
      }
      final from = _wallet(fromWalletId);
      final to = _wallet(toWalletId);
      if (!allowSavingsSource) {
        _requireNotSavings(from, 'transfer_from_savings',
            'Tiền chỉ ra khỏi ví tiết kiệm qua chức năng Rút tiền');
      }
      if (!allowSavingsDestination) {
        _requireNotSavings(to, 'transfer_into_savings',
            'Tiền vào ví tiết kiệm phải đi qua chức năng Tiết kiệm');
      }
      final sameCurrency = from['currency_code'] == to['currency_code'];
      final int received;
      if (sameCurrency) {
        if (destinationAmountMinor != null &&
            destinationAmountMinor != amountMinor) {
          throw FinanceException('amount_mismatch',
              'Cùng loại tiền thì số nhận phải bằng số chuyển');
        }
        received = amountMinor;
      } else {
        if (destinationAmountMinor == null) {
          throw FinanceException('destination_amount_required',
              'Khác loại tiền thì phải nhập số tiền ví nhận được');
        }
        _requirePositive(destinationAmountMinor);
        received = destinationAmountMinor;
      }
      if (requireSufficientFunds || from['type'] == 'SAVINGS') {
        _requireFunds(fromWalletId, amountMinor);
      }
      final id = _newId();
      _db.execute(
        'INSERT INTO transactions (id, request_id, type, source_wallet_id, '
        'destination_wallet_id, amount_minor, destination_amount_minor, '
        "transaction_date, note, created_at) VALUES (?, ?, 'TRANSFER', ?, ?, ?, ?, ?, ?, ?)",
        [
          id,
          requestId,
          fromWalletId,
          toWalletId,
          amountMinor,
          received,
          date,
          note,
          _now(),
        ],
      );
      debugHook?.call('transfer_inserted');
      return id;
    });
  }

  /// Sửa một khoản thu, chi hoặc chuyển ví thường. Không đổi được loại giao
  /// dịch. Lần góp và rút tiết kiệm không sửa ở đây: xóa rồi làm lại, để liên
  /// kết với mục tiêu luôn đúng.
  ///
  /// Thu, chi: [walletId] là ví của giao dịch. Chuyển ví: [walletId] là ví
  /// nguồn, [toWalletId] là ví nhận.
  void updateTransaction(
    String transactionId, {
    required String walletId,
    String? toWalletId,
    required int amountMinor,
    int? destinationAmountMinor,
    required String date,
    String? categoryId,
    String? note,
  }) {
    _inTransaction(() {
      final rows = _db.select(
          'SELECT id, type, source_wallet_id, destination_wallet_id, '
          'deleted_at FROM transactions WHERE id = ?',
          [transactionId]);
      if (rows.isEmpty) {
        throw FinanceException(
            'transaction_not_found', 'Không tìm thấy giao dịch');
      }
      final old = rows.first;
      if (old['deleted_at'] != null) {
        throw FinanceException(
            'transaction_deleted', 'Giao dịch này đã bị xóa');
      }
      final linked = _db.select(
          'SELECT 1 FROM savings_contributions WHERE transaction_id = ?1 '
          'UNION ALL SELECT 1 FROM savings_withdrawals WHERE transaction_id = ?1',
          [transactionId]);
      final oldWallets = [
        old['source_wallet_id'] as String?,
        old['destination_wallet_id'] as String?,
      ];
      final touchesSavings = oldWallets
          .whereType<String>()
          .any((id) => _walletRow(id)['type'] == 'SAVINGS');
      if (linked.isNotEmpty || touchesSavings) {
        throw FinanceException('savings_not_editable',
            'Lần góp hoặc rút tiết kiệm không sửa được. Hãy xóa rồi làm lại.');
      }
      _requirePositive(amountMinor);
      if (categoryId != null) _categoryRow(categoryId);
      final type = old['type'] as String;
      final wallet = _wallet(walletId);
      switch (type) {
        case 'INCOME':
          _requireNotSavings(wallet, 'income_into_savings',
              'Tiền vào ví tiết kiệm phải đi qua chức năng Tiết kiệm');
          _db.execute(
              'UPDATE transactions SET destination_wallet_id = ?, '
              'category_id = ?, amount_minor = ?, transaction_date = ?, '
              'note = ? WHERE id = ?',
              [walletId, categoryId, amountMinor, date, note, transactionId]);
        case 'EXPENSE':
          _requireNotSavings(wallet, 'expense_from_savings',
              'Không ghi chi tiêu trực tiếp từ ví tiết kiệm');
          _db.execute(
              'UPDATE transactions SET source_wallet_id = ?, '
              'category_id = ?, amount_minor = ?, transaction_date = ?, '
              'note = ? WHERE id = ?',
              [walletId, categoryId, amountMinor, date, note, transactionId]);
        default:
          if (toWalletId == null || toWalletId == walletId) {
            throw FinanceException(
                'same_wallet', 'Ví nguồn và ví nhận phải khác nhau');
          }
          final to = _wallet(toWalletId);
          _requireNotSavings(wallet, 'transfer_from_savings',
              'Tiền chỉ ra khỏi ví tiết kiệm qua chức năng Rút tiền');
          _requireNotSavings(to, 'transfer_into_savings',
              'Tiền vào ví tiết kiệm phải đi qua chức năng Tiết kiệm');
          final int received;
          if (wallet['currency_code'] == to['currency_code']) {
            received = amountMinor;
          } else {
            if (destinationAmountMinor == null) {
              throw FinanceException('destination_amount_required',
                  'Khác loại tiền thì phải nhập số tiền ví nhận được');
            }
            _requirePositive(destinationAmountMinor);
            received = destinationAmountMinor;
          }
          _db.execute(
              'UPDATE transactions SET source_wallet_id = ?, '
              'destination_wallet_id = ?, amount_minor = ?, '
              'destination_amount_minor = ?, transaction_date = ?, note = ? '
              'WHERE id = ?',
              [walletId, toWalletId, amountMinor, received, date, note,
                transactionId]);
      }
      final changed = <String>{
        ...oldWallets.whereType<String>(),
        walletId,
        if (toWalletId != null && type == 'TRANSFER') toWalletId,
      };
      for (final listener in _listeners) {
        listener(changed);
      }
      debugHook?.call('transaction_updated');
    });
  }

  /// Xóa mềm một giao dịch. Bị chặn nếu việc xóa làm ví tiết kiệm bị âm hoặc
  /// làm lệch số tiền của mục tiêu.
  void deleteTransaction(String transactionId) {
    _inTransaction(() {
      final tx = _transaction(transactionId);
      if (tx['deleted_at'] != null) return;
      _db.execute('UPDATE transactions SET deleted_at = ? WHERE id = ?',
          [_now(), transactionId]);
      _afterBalanceChange(tx);
      debugHook?.call('transaction_deleted');
    });
  }

  /// Hoàn tác một lần xóa, với cùng điều kiện như khi xóa.
  void restoreTransaction(String transactionId) {
    _inTransaction(() {
      final tx = _transaction(transactionId);
      if (tx['deleted_at'] == null) return;
      _db.execute('UPDATE transactions SET deleted_at = NULL WHERE id = ?',
          [transactionId]);
      _afterBalanceChange(tx);
      debugHook?.call('transaction_restored');
    });
  }

  /// Số giao dịch chưa bị xóa. Dùng trong kiểm thử chống trùng.
  int activeTransactionCount() {
    final rows = _db.select(
        'SELECT COUNT(*) AS c FROM transactions WHERE deleted_at IS NULL');
    return rows.first['c'] as int;
  }

  // ------------------------------------------------------------ Báo cáo

  /// Tổng thu và chi của một tháng cho một loại tiền. Chuyển ví không được
  /// tính vào đây.
  MonthSummary monthSummary({
    required int year,
    required int month,
    required String currencyCode,
  }) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    final income = _db.select(
      'SELECT COALESCE(SUM(t.amount_minor), 0) AS total FROM transactions t '
      'JOIN wallets w ON w.id = t.destination_wallet_id '
      "WHERE t.type = 'INCOME' AND t.deleted_at IS NULL "
      'AND w.currency_code = ? AND t.transaction_date LIKE ?',
      [currencyCode, '$prefix%'],
    );
    final expense = _db.select(
      'SELECT COALESCE(SUM(t.amount_minor), 0) AS total FROM transactions t '
      'JOIN wallets w ON w.id = t.source_wallet_id '
      "WHERE t.type = 'EXPENSE' AND t.deleted_at IS NULL "
      'AND w.currency_code = ? AND t.transaction_date LIKE ?',
      [currencyCode, '$prefix%'],
    );
    return MonthSummary(
      incomeMinor: income.first['total'] as int,
      expenseMinor: expense.first['total'] as int,
    );
  }

  // ------------------------------------------------------------- Nội bộ

  T _inTransaction<T>(T Function() body) {
    if (_transactionDepth > 0) {
      final savepoint = 'sp_${_savepointCounter++}';
      _db.execute('SAVEPOINT $savepoint');
      _transactionDepth++;
      try {
        final result = body();
        _db.execute('RELEASE $savepoint');
        return result;
      } catch (_) {
        _db.execute('ROLLBACK TO $savepoint');
        _db.execute('RELEASE $savepoint');
        rethrow;
      } finally {
        _transactionDepth--;
      }
    }
    _db.execute('BEGIN IMMEDIATE');
    _transactionDepth++;
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      _transactionDepth--;
    }
  }

  void _afterBalanceChange(Row tx) {
    final source = tx['source_wallet_id'] as String?;
    final destination = tx['destination_wallet_id'] as String?;
    _requireSavingsNonNegative(source);
    _requireSavingsNonNegative(destination);
    final wallets = <String>{
      if (source != null) source,
      if (destination != null) destination,
    };
    for (final listener in _listeners) {
      listener(wallets);
    }
  }

  String? _findByRequestId(String requestId) {
    final rows = _db
        .select('SELECT id FROM transactions WHERE request_id = ?', [requestId]);
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  Row _walletRow(String walletId) {
    final rows = _db.select(
        'SELECT id, type, currency_code, is_archived FROM wallets WHERE id = ?',
        [walletId]);
    if (rows.isEmpty) {
      throw FinanceException('wallet_not_found', 'Không tìm thấy ví');
    }
    return rows.first;
  }

  /// Ví dùng được cho giao dịch mới: tồn tại và chưa lưu trữ.
  Row _wallet(String walletId) {
    final row = _walletRow(walletId);
    if (row['is_archived'] == 1) {
      throw FinanceException('wallet_archived', 'Ví đã được lưu trữ');
    }
    return row;
  }

  Row _categoryRow(String categoryId) {
    final rows =
        _db.select('SELECT id FROM categories WHERE id = ?', [categoryId]);
    if (rows.isEmpty) {
      throw FinanceException('category_not_found', 'Không tìm thấy danh mục');
    }
    return rows.first;
  }

  Row _transaction(String transactionId) {
    final rows = _db.select(
        'SELECT id, source_wallet_id, destination_wallet_id, deleted_at '
        'FROM transactions WHERE id = ?',
        [transactionId]);
    if (rows.isEmpty) {
      throw FinanceException(
          'transaction_not_found', 'Không tìm thấy giao dịch');
    }
    return rows.first;
  }

  void _requireName(String name) {
    if (name.trim().isEmpty) {
      throw FinanceException('invalid_name', 'Tên không được để trống');
    }
  }

  void _requirePositive(int amountMinor) {
    if (amountMinor <= 0) {
      throw FinanceException('invalid_amount', 'Số tiền phải lớn hơn 0');
    }
    if (amountMinor > maxAmountMinor) {
      throw FinanceException('amount_too_large', 'Số tiền quá lớn');
    }
  }

  void _requireNotSavings(Row wallet, String code, String message) {
    if (wallet['type'] == 'SAVINGS') {
      throw FinanceException(code, message);
    }
  }

  void _requireFunds(String walletId, int amountMinor) {
    final balance = walletBalance(walletId);
    if (balance < amountMinor) {
      final rows = _db.select(
          'SELECT currency_code FROM wallets WHERE id = ?', [walletId]);
      throw InsufficientFundsException(balance, amountMinor - balance,
          currency: rows.first['currency_code'] as String);
    }
  }

  void _requireSavingsNonNegative(String? walletId) {
    if (walletId == null) return;
    if (_walletRow(walletId)['type'] != 'SAVINGS') return;
    final balance = walletBalance(walletId);
    if (balance < 0) {
      throw FinanceException('would_go_negative',
          'Thao tác này làm ví tiết kiệm bị âm ($balance)');
    }
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

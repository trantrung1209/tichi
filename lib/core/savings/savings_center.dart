/// Tichi – Savings Center: nghiệp vụ mục tiêu tiết kiệm.
///
/// Quy tắc (xem tài liệu Tichi v1, mục 5):
/// - Mỗi lần "Tiết kiệm ngay" là một lần chuyển ví thật vào ví tiết kiệm.
/// - Mục tiêu không giữ tiền; nó ghi lại phần nào trong ví tiết kiệm thuộc về
///   nó. Phần còn lại của ví là "Chưa gắn mục tiêu".
/// - Tổng đã tiết kiệm của các mục tiêu trong một ví không bao giờ vượt số dư
///   của ví đó, và không mục tiêu nào bị âm.
/// - Tiết kiệm và rút tiền chỉ giữa các ví cùng loại tiền.
/// - Mọi thao tác chạy trong một transaction: ghi trọn vẹn hoặc không ghi gì.
library;

import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../finance/finance_core.dart';
import '../finance/schema.dart';

class GoalProgress {
  const GoalProgress({
    required this.goalId,
    required this.name,
    required this.currencyCode,
    required this.savedMinor,
    required this.targetMinor,
    required this.status,
    required this.icon,
    required this.startDate,
    required this.targetDate,
    required this.priority,
    required this.savingsWalletId,
  });

  final String goalId;
  final String name;
  final String currencyCode;
  final int savedMinor;
  final int targetMinor;
  final String status;
  final String icon;
  final String startDate;
  final String targetDate;
  final int priority;
  final String savingsWalletId;

  int get remainingMinor => max(0, targetMinor - savedMinor);

  /// Phần trăm hoàn thành, làm tròn xuống, tối đa 100.
  int get percent => min(100, savedMinor * 100 ~/ targetMinor);
}

/// Số tiền nên tiết kiệm để kịp hạn. Không có giá trị (null) khi mục tiêu đã
/// đủ tiền hoặc đã quá hạn.
class SavingsSuggestion {
  const SavingsSuggestion({
    required this.daysLeft,
    required this.remainingMinor,
    required this.dailyMinor,
    required this.weeklyMinor,
    required this.monthlyMinor,
  });

  /// Số ngày còn lại, tính cả hôm nay và ngày hoàn thành.
  final int daysLeft;
  final int remainingMinor;
  final int dailyMinor;
  final int weeklyMinor;

  /// Tính theo tháng 30 ngày, đủ dùng cho số gợi ý.
  final int monthlyMinor;
}

/// Một dòng trong lịch sử của mục tiêu. [amountMinor] dương là tiền vào,
/// âm là tiền rút ra.
class GoalEvent {
  const GoalEvent({
    required this.date,
    required this.amountMinor,
    required this.kind,
    required this.walletName,
  });

  final String date;
  final int amountMinor;

  /// CONTRIBUTION (chuyển từ ví khác), ALLOCATION (chia từ tiền có sẵn),
  /// WITHDRAWAL (rút ra).
  final String kind;
  final String? walletName;
}

class SavingsCenter {
  SavingsCenter(this._core) {
    _core.addWalletsChangedListener(_onWalletsChanged);
  }

  final FinanceCore _core;
  final Random _random = Random.secure();

  Database get _db => _core.db;

  // ------------------------------------------------------------ Mục tiêu

  String createGoal({
    required String name,
    required int targetMinor,
    required String savingsWalletId,
    required String startDate,
    required String targetDate,
    int priority = 1,
    String icon = 'savings',
  }) {
    if (name.trim().isEmpty) {
      throw FinanceException('invalid_name', 'Tên mục tiêu không được trống');
    }
    if (targetMinor <= 0) {
      throw FinanceException('invalid_amount', 'Số tiền mục tiêu phải lớn hơn 0');
    }
    final start = _parseDate(startDate);
    final target = _parseDate(targetDate);
    if (target.isBefore(start)) {
      throw FinanceException(
          'invalid_dates', 'Ngày hoàn thành phải sau ngày bắt đầu');
    }
    final wallet = _savingsWallet(savingsWalletId);
    if (wallet['is_archived'] == 1) {
      throw FinanceException('wallet_archived', 'Ví đã được lưu trữ');
    }
    final id = _newId();
    final now = _now();
    _db.execute(
      'INSERT INTO savings_goals (id, name, target_amount_minor, '
      'savings_wallet_id, start_date, target_date, priority, icon, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        name.trim(),
        targetMinor,
        savingsWalletId,
        startDate,
        targetDate,
        priority,
        icon,
        now,
        now,
      ],
    );
    return id;
  }

  /// Sửa tên, số tiền mục tiêu, ngày hoàn thành, mức ưu tiên hoặc biểu
  /// tượng. Ví tiết kiệm của mục tiêu không đổi được.
  void updateGoal(
    String goalId, {
    String? name,
    int? targetMinor,
    String? targetDate,
    int? priority,
    String? icon,
  }) {
    _core.runInTransaction(() {
      final goal = _goal(goalId);
      if (name != null && name.trim().isEmpty) {
        throw FinanceException('invalid_name', 'Tên mục tiêu không được trống');
      }
      if (targetMinor != null && targetMinor <= 0) {
        throw FinanceException(
            'invalid_amount', 'Số tiền mục tiêu phải lớn hơn 0');
      }
      if (targetDate != null &&
          _parseDate(targetDate)
              .isBefore(_parseDate(goal['start_date'] as String))) {
        throw FinanceException(
            'invalid_dates', 'Ngày hoàn thành phải sau ngày bắt đầu');
      }
      _db.execute(
        'UPDATE savings_goals SET name = COALESCE(?, name), '
        'target_amount_minor = COALESCE(?, target_amount_minor), '
        'target_date = COALESCE(?, target_date), '
        'priority = COALESCE(?, priority), icon = COALESCE(?, icon), '
        'updated_at = ? WHERE id = ?',
        [name?.trim(), targetMinor, targetDate, priority, icon, _now(), goalId],
      );
      _refreshStatuses(goal['savings_wallet_id'] as String);
    });
  }

  /// Lịch sử góp, chia và rút của mục tiêu, mới nhất trước. Lần nào mà giao
  /// dịch gốc đã bị xóa thì không hiện.
  List<GoalEvent> history(String goalId) {
    final rows = _db.select(
      "SELECT c.contribution_date AS d, c.amount_minor AS a, "
      "CASE WHEN c.transaction_id IS NULL THEN 'ALLOCATION' "
      "ELSE 'CONTRIBUTION' END AS k, w.name AS wallet, c.created_at AS ca "
      'FROM savings_contributions c '
      'LEFT JOIN transactions t ON t.id = c.transaction_id '
      'LEFT JOIN wallets w ON w.id = t.source_wallet_id '
      'WHERE c.goal_id = ?1 '
      'AND (c.transaction_id IS NULL OR t.deleted_at IS NULL) '
      'UNION ALL '
      "SELECT wd.withdrawal_date, -wd.amount_minor, 'WITHDRAWAL', w.name, "
      'wd.created_at FROM savings_withdrawals wd '
      'JOIN transactions t ON t.id = wd.transaction_id '
      'JOIN wallets w ON w.id = t.destination_wallet_id '
      'WHERE wd.goal_id = ?1 AND t.deleted_at IS NULL '
      'ORDER BY d DESC, ca DESC',
      [goalId],
    );
    return [
      for (final row in rows)
        GoalEvent(
          date: row['d'] as String,
          amountMinor: row['a'] as int,
          kind: row['k'] as String,
          walletName: row['wallet'] as String?,
        ),
    ];
  }

  /// Xóa mục tiêu. Tiền của nó vẫn nằm trong ví tiết kiệm và trở về
  /// "Chưa gắn mục tiêu". Lịch sử góp và rút được giữ lại.
  void deleteGoal(String goalId) {
    _core.runInTransaction(() {
      _goal(goalId);
      _db.execute(
          'UPDATE savings_goals SET deleted_at = ?, updated_at = ? WHERE id = ?',
          [_now(), _now(), goalId]);
    });
  }

  /// Số tiền đã tiết kiệm của mục tiêu.
  int savedMinor(String goalId) {
    final rows = _db.select(goalSavedSql, [goalId]);
    return rows.first['saved'] as int;
  }

  GoalProgress progress(String goalId) {
    final goal = _goal(goalId);
    final wallet = _savingsWallet(goal['savings_wallet_id'] as String);
    return GoalProgress(
      goalId: goalId,
      name: goal['name'] as String,
      currencyCode: wallet['currency_code'] as String,
      savedMinor: savedMinor(goalId),
      targetMinor: goal['target_amount_minor'] as int,
      status: goal['status'] as String,
      icon: goal['icon'] as String,
      startDate: goal['start_date'] as String,
      targetDate: goal['target_date'] as String,
      priority: goal['priority'] as int,
      savingsWalletId: goal['savings_wallet_id'] as String,
    );
  }

  /// Các mục tiêu chưa xóa, ưu tiên cao trước rồi tới mục tiêu tạo trước.
  List<GoalProgress> goals() {
    final rows = _db.select(
        'SELECT id FROM savings_goals WHERE deleted_at IS NULL '
        'ORDER BY priority DESC, created_at');
    return [for (final row in rows) progress(row['id'] as String)];
  }

  /// Phần tiền trong ví tiết kiệm chưa thuộc mục tiêu nào.
  int unallocatedMinor(String savingsWalletId) {
    _savingsWallet(savingsWalletId);
    return _core.walletBalance(savingsWalletId) -
        _allocatedMinor(savingsWalletId);
  }

  // -------------------------------------------------- Tiết kiệm và rút

  /// "Tiết kiệm ngay": chuyển tiền thật từ [fromWalletId] vào ví tiết kiệm
  /// của mục tiêu và ghi nhận cho mục tiêu đó. Trả về mã lần góp.
  ///
  /// Gọi lại với cùng [requestId] trả về lần góp cũ, không chuyển thêm tiền.
  String contribute({
    required String requestId,
    required String goalId,
    required String fromWalletId,
    required int amountMinor,
    required String date,
    String? note,
  }) {
    return _core.runInTransaction(() {
      final existing = _contributionByRequest(requestId);
      if (existing != null) return existing;
      _parseDate(date);
      final goal = _activeGoal(goalId);
      final savingsWalletId = goal['savings_wallet_id'] as String;
      _requireSameCurrency(fromWalletId, savingsWalletId);
      final transactionId = _core.transfer(
        requestId: requestId,
        fromWalletId: fromWalletId,
        toWalletId: savingsWalletId,
        amountMinor: amountMinor,
        date: date,
        note: note,
        allowSavingsDestination: true,
        requireSufficientFunds: true,
      );
      final id = _newId();
      _db.execute(
        'INSERT INTO savings_contributions (id, request_id, goal_id, '
        'transaction_id, amount_minor, contribution_date, note, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [id, requestId, goalId, transactionId, amountMinor, date, note, _now()],
      );
      _core.debugHook?.call('contribution_inserted');
      _refreshStatuses(savingsWalletId);
      _checkWallet(savingsWalletId);
      return id;
    });
  }

  /// Chia tiền "Chưa gắn mục tiêu" có sẵn trong ví tiết kiệm cho một mục
  /// tiêu. Không có chuyển ví, nên không tính vào chuỗi ngày tiết kiệm.
  String allocateUnassigned({
    required String requestId,
    required String goalId,
    required int amountMinor,
    required String date,
    String? note,
  }) {
    return _core.runInTransaction(() {
      final existing = _contributionByRequest(requestId);
      if (existing != null) return existing;
      _parseDate(date);
      if (amountMinor <= 0) {
        throw FinanceException('invalid_amount', 'Số tiền phải lớn hơn 0');
      }
      final goal = _activeGoal(goalId);
      final savingsWalletId = goal['savings_wallet_id'] as String;
      final free = unallocatedMinor(savingsWalletId);
      if (amountMinor > free) {
        throw FinanceException('exceeds_unallocated',
            'Chỉ còn $free chưa gắn mục tiêu');
      }
      final id = _newId();
      _db.execute(
        'INSERT INTO savings_contributions (id, request_id, goal_id, '
        'transaction_id, amount_minor, contribution_date, note, created_at) '
        'VALUES (?, ?, ?, NULL, ?, ?, ?, ?)',
        [id, requestId, goalId, amountMinor, date, note, _now()],
      );
      _refreshStatuses(savingsWalletId);
      _checkWallet(savingsWalletId);
      return id;
    });
  }

  /// Rút tiền của một mục tiêu về ví thường [toWalletId]. Chỉ mục tiêu đó bị
  /// giảm. Trả về mã lần rút.
  String withdraw({
    required String requestId,
    required String goalId,
    required String toWalletId,
    required int amountMinor,
    required String date,
    String? note,
  }) {
    return _core.runInTransaction(() {
      final existing = _withdrawalByRequest(requestId);
      if (existing != null) return existing;
      _parseDate(date);
      if (amountMinor <= 0) {
        throw FinanceException('invalid_amount', 'Số tiền phải lớn hơn 0');
      }
      final goal = _goal(goalId);
      final savingsWalletId = goal['savings_wallet_id'] as String;
      final saved = savedMinor(goalId);
      if (amountMinor > saved) {
        throw FinanceException('exceeds_goal_savings',
            'Mục tiêu này chỉ có $saved');
      }
      _requireSameCurrency(savingsWalletId, toWalletId);
      final transactionId = _core.transfer(
        requestId: requestId,
        fromWalletId: savingsWalletId,
        toWalletId: toWalletId,
        amountMinor: amountMinor,
        date: date,
        note: note,
        allowSavingsSource: true,
      );
      final id = _newId();
      _db.execute(
        'INSERT INTO savings_withdrawals (id, request_id, goal_id, '
        'transaction_id, amount_minor, withdrawal_date, note, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [id, requestId, goalId, transactionId, amountMinor, date, note, _now()],
      );
      _core.debugHook?.call('withdrawal_inserted');
      _refreshStatuses(savingsWalletId);
      _checkWallet(savingsWalletId);
      return id;
    });
  }

  /// Rút phần "Chưa gắn mục tiêu" về ví thường. Trả về mã giao dịch.
  String withdrawUnassigned({
    required String requestId,
    required String savingsWalletId,
    required String toWalletId,
    required int amountMinor,
    required String date,
    String? note,
  }) {
    return _core.runInTransaction(() {
      final existing = _core.transactionIdForRequest(requestId);
      if (existing != null) return existing;
      final free = unallocatedMinor(savingsWalletId);
      if (amountMinor > free) {
        throw FinanceException('exceeds_unallocated',
            'Chỉ còn $free chưa gắn mục tiêu');
      }
      _requireSameCurrency(savingsWalletId, toWalletId);
      final transactionId = _core.transfer(
        requestId: requestId,
        fromWalletId: savingsWalletId,
        toWalletId: toWalletId,
        amountMinor: amountMinor,
        date: date,
        note: note,
        allowSavingsSource: true,
      );
      _checkWallet(savingsWalletId);
      return transactionId;
    });
  }

  // ------------------------------------------------- Gợi ý và chuỗi ngày

  /// Số tiền nên tiết kiệm để kịp hạn, tính từ ngày [today] (dạng
  /// YYYY-MM-DD). Null khi đã đủ tiền hoặc đã quá hạn.
  SavingsSuggestion? suggestion(String goalId, String today) {
    final goal = _goal(goalId);
    final remaining = (goal['target_amount_minor'] as int) - savedMinor(goalId);
    if (remaining <= 0) return null;
    final daysLeft = _parseDate(goal['target_date'] as String)
            .difference(_parseDate(today))
            .inDays +
        1;
    if (daysLeft <= 0) return null;
    return SavingsSuggestion(
      daysLeft: daysLeft,
      remainingMinor: remaining,
      dailyMinor: _ceilDiv(remaining, daysLeft),
      weeklyMinor: _ceilDiv(remaining, _ceilDiv(daysLeft, 7)),
      monthlyMinor: _ceilDiv(remaining, _ceilDiv(daysLeft, 30)),
    );
  }

  /// Số ngày liên tiếp có ít nhất một lần tiết kiệm thật (chuyển ví), cho bất
  /// kỳ mục tiêu nào. Hôm nay chưa tiết kiệm thì chuỗi vẫn giữ từ hôm qua.
  ///
  /// [period] là 'daily' (đếm ngày), 'weekly' (đếm tuần, tuần bắt đầu thứ
  /// Hai) hoặc 'monthly' (đếm tháng). Kỳ hiện tại chưa góp thì vẫn tính
  /// chuỗi tới kỳ trước, để chuỗi không bị đứt khi kỳ này chưa kết thúc.
  int currentStreak(String today, {String period = 'daily'}) {
    final rows = _db.select(
      'SELECT DISTINCT c.contribution_date AS d FROM savings_contributions c '
      'JOIN transactions t ON t.id = c.transaction_id '
      'WHERE t.deleted_at IS NULL',
    );
    final days = {for (final row in rows) row['d'] as String};
    if (period == 'weekly' || period == 'monthly') {
      final weekly = period == 'weekly';
      DateTime start(DateTime d) => weekly
          ? d.subtract(Duration(days: d.weekday - 1))
          : DateTime.utc(d.year, d.month, 1);
      DateTime previous(DateTime d) => weekly
          ? d.subtract(const Duration(days: 7))
          : DateTime.utc(d.year, d.month - 1, 1);
      final periods = {for (final d in days) _formatDate(start(_parseDate(d)))};
      var cursor = start(_parseDate(today));
      if (!periods.contains(_formatDate(cursor))) cursor = previous(cursor);
      var count = 0;
      while (periods.contains(_formatDate(cursor))) {
        count++;
        cursor = previous(cursor);
      }
      return count;
    }
    var cursor = _parseDate(today);
    if (!days.contains(_formatDate(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ------------------------------------------------------------- Nội bộ

  /// Gọi khi một giao dịch bị xóa hoặc khôi phục. Ném lỗi nếu việc đó làm
  /// một mục tiêu bị âm hoặc ví tiết kiệm không đủ tiền cho các mục tiêu.
  void _onWalletsChanged(Set<String> walletIds) {
    for (final walletId in walletIds) {
      final rows = _db.select('SELECT type FROM wallets WHERE id = ?', [walletId]);
      if (rows.isEmpty || rows.first['type'] != 'SAVINGS') continue;
      _checkWallet(walletId);
      _refreshStatuses(walletId);
    }
  }

  void _checkWallet(String savingsWalletId) {
    for (final goalId in _goalIds(savingsWalletId)) {
      final saved = savedMinor(goalId);
      if (saved < 0) {
        throw FinanceException('goal_would_go_negative',
            'Thao tác này làm số tiết kiệm của một mục tiêu bị âm');
      }
    }
    final balance = _core.walletBalance(savingsWalletId);
    final allocated = _allocatedMinor(savingsWalletId);
    if (allocated > balance) {
      throw FinanceException('savings_overallocated',
          'Tổng của các mục tiêu ($allocated) vượt số dư ví ($balance)');
    }
  }

  /// Mục tiêu đủ tiền thì chuyển sang Hoàn thành; bị rút xuống dưới mức thì
  /// trở lại Đang thực hiện. Mục tiêu tạm dừng hoặc lưu trữ giữ nguyên.
  void _refreshStatuses(String savingsWalletId) {
    for (final goalId in _goalIds(savingsWalletId)) {
      final goal = _goal(goalId);
      final status = goal['status'] as String;
      if (status != 'ACTIVE' && status != 'COMPLETED') continue;
      final reached = savedMinor(goalId) >= (goal['target_amount_minor'] as int);
      final next = reached ? 'COMPLETED' : 'ACTIVE';
      if (next != status) {
        _db.execute(
            'UPDATE savings_goals SET status = ?, updated_at = ? WHERE id = ?',
            [next, _now(), goalId]);
      }
    }
  }

  int _allocatedMinor(String savingsWalletId) {
    var total = 0;
    for (final goalId in _goalIds(savingsWalletId)) {
      total += savedMinor(goalId);
    }
    return total;
  }

  List<String> _goalIds(String savingsWalletId) {
    final rows = _db.select(
        'SELECT id FROM savings_goals '
        'WHERE savings_wallet_id = ? AND deleted_at IS NULL',
        [savingsWalletId]);
    return [for (final row in rows) row['id'] as String];
  }

  Row _goal(String goalId) {
    final rows = _db.select(
        'SELECT * FROM savings_goals WHERE id = ? AND deleted_at IS NULL',
        [goalId]);
    if (rows.isEmpty) {
      throw FinanceException('goal_not_found', 'Không tìm thấy mục tiêu');
    }
    return rows.first;
  }

  /// Mục tiêu nhận thêm tiền được: chưa xóa và chưa lưu trữ.
  Row _activeGoal(String goalId) {
    final goal = _goal(goalId);
    if (goal['status'] == 'ARCHIVED') {
      throw FinanceException('goal_archived', 'Mục tiêu đã được lưu trữ');
    }
    return goal;
  }

  Row _savingsWallet(String walletId) {
    final rows = _db.select(
        'SELECT id, type, currency_code, is_archived FROM wallets WHERE id = ?',
        [walletId]);
    if (rows.isEmpty) {
      throw FinanceException('wallet_not_found', 'Không tìm thấy ví');
    }
    if (rows.first['type'] != 'SAVINGS') {
      throw FinanceException(
          'not_savings_wallet', 'Mục tiêu phải gắn với một ví tiết kiệm');
    }
    return rows.first;
  }

  void _requireSameCurrency(String walletA, String walletB) {
    final rows = _db.select(
        'SELECT id, currency_code FROM wallets WHERE id IN (?, ?)',
        [walletA, walletB]);
    if (rows.length < 2 && walletA != walletB) {
      throw FinanceException('wallet_not_found', 'Không tìm thấy ví');
    }
    final currencies = {for (final row in rows) row['currency_code'] as String};
    if (currencies.length > 1) {
      throw FinanceException('currency_mismatch',
          'Tiết kiệm và rút tiền chỉ giữa các ví cùng loại tiền');
    }
  }

  String? _contributionByRequest(String requestId) {
    final rows = _db.select(
        'SELECT id FROM savings_contributions WHERE request_id = ?',
        [requestId]);
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  String? _withdrawalByRequest(String requestId) {
    final rows = _db.select(
        'SELECT id FROM savings_withdrawals WHERE request_id = ?', [requestId]);
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  DateTime _parseDate(String value) {
    if (!_datePattern.hasMatch(value)) {
      throw FinanceException('invalid_date', 'Ngày phải có dạng YYYY-MM-DD');
    }
    final parts = value.split('-').map(int.parse).toList();
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    if (_formatDate(date) != value) {
      throw FinanceException('invalid_date', 'Ngày không tồn tại: $value');
    }
    return date;
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;

  int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  String _newId() {
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

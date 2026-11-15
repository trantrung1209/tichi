/// Tichi – sao lưu và khôi phục.
///
/// File sao lưu (đuôi .tichi) là bản chụp toàn bộ cơ sở dữ liệu, mã hóa bằng
/// AES-256-GCM với khóa sinh từ mật khẩu của người dùng (PBKDF2-HMAC-SHA256).
/// Không có mật khẩu thì không đọc được, kể cả nhà phát triển.
///
/// Cấu trúc file:
///   8 byte  "TICHIBK1"
///   4 byte  số vòng PBKDF2 (big-endian)
///   16 byte salt
///   12 byte nonce
///   16 byte mã xác thực (MAC)
///   phần còn lại: dữ liệu đã mã hóa
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

import '../finance/finance_core.dart';
import '../finance/schema.dart';
import '../l10n.dart';

const List<int> _magic = [0x54, 0x49, 0x43, 0x48, 0x49, 0x42, 0x4B, 0x31];
const int _headerLength = 8 + 4 + 16 + 12 + 16;
const int minPasswordLength = 6;

/// Bảng theo thứ tự cha trước con, để chép dữ liệu không vi phạm khóa ngoại.
const List<String> _tablesInOrder = [
  'wallets',
  'categories',
  'transactions',
  'savings_goals',
  'savings_contributions',
  'savings_withdrawals',
  'budgets',
  'app_settings',
];

/// Thông tin xem trước của một file sao lưu đã giải mã.
class BackupPreview {
  const BackupPreview({
    required this.walletCount,
    required this.transactionCount,
    required this.goalCount,
    required this.latestTransactionDate,
    required this.schemaVersion,
  });

  final int walletCount;
  final int transactionCount;
  final int goalCount;
  final String? latestTransactionDate;
  final int schemaVersion;
}

/// File sao lưu đã giải mã và kiểm tra, chờ người dùng xác nhận khôi phục.
class RestorePlan {
  RestorePlan._(this._path, this.preview);

  final String _path;
  final BackupPreview preview;
}

class BackupService {
  BackupService(this._core, {this.iterations = 120000});

  final FinanceCore _core;

  /// Số vòng PBKDF2. Càng nhiều càng khó dò mật khẩu nhưng càng chậm; kiểm
  /// thử dùng số nhỏ cho nhanh.
  final int iterations;

  final Random _random = Random.secure();

  Database get _db => _core.db;

  // ------------------------------------------------------------- Sao lưu

  /// Tạo nội dung file sao lưu đã mã hóa. [tempDir] là nơi đặt file tạm.
  Future<Uint8List> createBackup(String password, Directory tempDir) async {
    _requirePassword(password);
    final snapshot = File(
        '${tempDir.path}/tichi_snapshot_${DateTime.now().microsecondsSinceEpoch}.db');
    try {
      _db.execute('VACUUM INTO ?', [snapshot.path]);
      final plain = await snapshot.readAsBytes();
      return await _encrypt(plain, password);
    } finally {
      if (snapshot.existsSync()) snapshot.deleteSync();
    }
  }

  // ---------------------------------------------------------- Khôi phục

  /// Giải mã, kiểm tra và nâng cấp bản sao lưu lên phiên bản hiện tại. Chưa
  /// thay đổi gì dữ liệu đang dùng. Gọi [applyRestore] để khôi phục thật,
  /// hoặc [discard] để bỏ.
  Future<RestorePlan> openBackup(
      Uint8List fileBytes, String password, Directory tempDir) async {
    final plain = await _decrypt(fileBytes, password);
    final path =
        '${tempDir.path}/tichi_restore_${DateTime.now().microsecondsSinceEpoch}.db';
    await File(path).writeAsBytes(plain, flush: true);
    try {
      final source = sqlite3.open(path);
      try {
        final check = source.select('PRAGMA integrity_check');
        if (check.isEmpty || check.first.values.first != 'ok') {
          throw FinanceException('backup_corrupt', 'File sao lưu bị hỏng.');
        }
        final version = source.userVersion;
        if (version < 1) {
          throw FinanceException(
              'backup_invalid', 'Đây không phải file sao lưu của Tichi.');
        }
        if (version > schemaVersion) {
          throw FinanceException('backup_too_new',
              'File sao lưu tạo từ bản Tichi mới hơn. Hãy cập nhật app trước.');
        }
        // Nâng bản sao lưu cũ lên cùng phiên bản với app.
        FinanceCore(source).migrate();
        final preview = BackupPreview(
          walletCount: _count(source, 'wallets'),
          transactionCount: _count(source, 'transactions',
              where: 'deleted_at IS NULL'),
          goalCount: _count(source, 'savings_goals',
              where: 'deleted_at IS NULL'),
          latestTransactionDate: source
              .select('SELECT MAX(transaction_date) AS d FROM transactions '
                  'WHERE deleted_at IS NULL')
              .first['d'] as String?,
          schemaVersion: version,
        );
        return RestorePlan._(path, preview);
      } finally {
        source.close();
      }
    } catch (_) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
      rethrow;
    }
  }

  /// Thay toàn bộ dữ liệu hiện tại bằng dữ liệu trong bản sao lưu. Chạy trong
  /// một transaction: lỗi giữa chừng thì dữ liệu hiện tại giữ nguyên.
  void applyRestore(RestorePlan plan) {
    _db.execute('ATTACH DATABASE ? AS src', [plan._path]);
    try {
      _core.runInTransaction(() {
        _db.execute('PRAGMA defer_foreign_keys = ON');
        for (final table in _tablesInOrder.reversed) {
          _db.execute('DELETE FROM main.$table');
        }
        for (final table in _tablesInOrder) {
          final columns = _db
              .select('PRAGMA main.table_info($table)')
              .map((row) => row['name'] as String)
              .join(', ');
          _db.execute(
              'INSERT INTO main.$table ($columns) SELECT $columns FROM src.$table');
        }
        final broken = _db.select('PRAGMA main.foreign_key_check');
        if (broken.isNotEmpty) {
          throw FinanceException(
              'backup_inconsistent', 'Dữ liệu trong file sao lưu không khớp.');
        }
      });
    } finally {
      _db.execute('DETACH DATABASE src');
      discard(plan);
    }
  }

  /// Xóa file tạm của một lần khôi phục không dùng tới.
  void discard(RestorePlan plan) {
    final file = File(plan._path);
    if (file.existsSync()) file.deleteSync();
  }

  // ----------------------------------------------------------- Xuất CSV

  /// Danh sách giao dịch dạng CSV (UTF-8 có BOM để Excel đọc đúng tiếng Việt).
  String exportCsv() {
    final rows = _core.transactions();
    final buffer = StringBuffer('﻿')
      ..writeln(_csvRow([
        tr('Ngày', 'Date'),
        tr('Loại', 'Type'),
        tr('Số tiền', 'Amount'),
        tr('Loại tiền', 'Currency'),
        tr('Danh mục', 'Category'),
        tr('Ví nguồn', 'From wallet'),
        tr('Ví nhận', 'To wallet'),
        tr('Ghi chú', 'Note'),
      ]));
    for (final tx in rows.reversed) {
      final type = switch (tx.type) {
        'INCOME' => tr('Thu', 'Income'),
        'EXPENSE' => tr('Chi', 'Expense'),
        _ => tx.destinationIsSavings
            ? tr('Tiết kiệm', 'Saving')
            : (tx.sourceIsSavings ? tr('Rút tiết kiệm', 'Withdrawal') : tr('Chuyển ví', 'Transfer')),
      };
      buffer.writeln(_csvRow([
        tx.date,
        type,
        _plainAmount(tx.amountMinor, tx.currency),
        tx.currency,
        tx.categoryName ?? '',
        tx.sourceWalletName ?? '',
        tx.destinationWalletName ?? '',
        tx.note ?? '',
      ]));
    }
    return buffer.toString();
  }

  // ------------------------------------------------------------- Nội bộ

  void _requirePassword(String password) {
    if (password.length < minPasswordLength) {
      throw FinanceException('weak_password',
          'Mật khẩu cần ít nhất $minPasswordLength ký tự.');
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt, int rounds) {
    final pbkdf2 =
        Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: rounds, bits: 256);
    return pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  }

  Future<Uint8List> _encrypt(List<int> plain, String password) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(password, salt, iterations);
    final box =
        await AesGcm.with256bits().encrypt(plain, secretKey: key, nonce: nonce);
    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add((ByteData(4)..setUint32(0, iterations)).buffer.asUint8List())
      ..add(salt)
      ..add(nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return out.toBytes();
  }

  Future<List<int>> _decrypt(Uint8List data, String password) async {
    if (data.length <= _headerLength ||
        !_startsWith(data, _magic)) {
      throw FinanceException(
          'backup_invalid', 'Đây không phải file sao lưu của Tichi.');
    }
    final rounds = ByteData.sublistView(data, 8, 12).getUint32(0);
    final salt = data.sublist(12, 28);
    final nonce = data.sublist(28, 40);
    final mac = data.sublist(40, 56);
    final cipherText = data.sublist(56);
    final key = await _deriveKey(password, salt, rounds);
    try {
      return await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw FinanceException('wrong_password',
          'Sai mật khẩu, hoặc file sao lưu đã bị thay đổi.');
    }
  }

  bool _startsWith(List<int> data, List<int> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));

  int _count(Database db, String table, {String? where}) {
    final rows = db.select(
        'SELECT COUNT(*) AS c FROM $table${where == null ? '' : ' WHERE $where'}');
    return rows.first['c'] as int;
  }

  String _plainAmount(int minor, String currency) {
    if (currency != 'USD') return '$minor';
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  String _csvRow(List<String> cells) => cells.map((cell) {
        if (cell.contains(',') ||
            cell.contains('"') ||
            cell.contains('\n') ||
            cell.contains('\r')) {
          return '"${cell.replaceAll('"', '""')}"';
        }
        return cell;
      }).join(',');
}

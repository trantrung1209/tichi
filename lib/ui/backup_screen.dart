/// Sao lưu, khôi phục và xuất CSV.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/backup/backup_service.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import 'icons.dart';
import 'widgets.dart';
import '../core/l10n.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
  }

  Future<void> _backup() async {
    final store = StoreScope.read(context);
    final password = await _askPassword(context, confirm: true);
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final temp = await getTemporaryDirectory();
      final bytes =
          await BackupService(store.core).createBackup(password, temp);
      final saved = await FilePicker.saveFile(
        dialogTitle: tr('Lưu file sao lưu', 'Save backup file'),
        fileName: 'tichi-saoluu-${_stamp()}.tichi',
        bytes: bytes,
      );
      if (saved != null) {
        store.markBackedUp(DateTime.now());
        _snack(tr('Đã lưu file sao lưu. Hãy giữ file và mật khẩu cẩn thận.', 'Backup saved. Keep the file and the password safe.'));
      }
    } on FinanceException catch (error) {
      _snack(friendlyError(error));
    } catch (_) {
      _snack(tr('Không lưu được file sao lưu.', 'Couldn\'t save the backup file.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await restoreFromBackupFile(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    final store = StoreScope.read(context);
    setState(() => _busy = true);
    try {
      final csv = BackupService(store.core).exportCsv();
      final saved = await FilePicker.saveFile(
        dialogTitle: tr('Lưu file CSV', 'Save CSV file'),
        fileName: 'tichi-giaodich-${_stamp()}.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (saved != null) _snack(tr('Đã xuất danh sách giao dịch.', 'Transactions exported.'));
    } catch (_) {
      _snack(tr('Không xuất được file CSV.', 'Couldn\'t export the CSV file.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final last = store.core.getSetting('last_backup_at');
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Sao lưu và khôi phục', 'Backup & restore'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (_busy) const LinearProgressIndicator(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const IconAvatar(icon: 'insurance', color: 'emerald'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          last == null
                              ? tr('Bạn chưa sao lưu lần nào. Dữ liệu chỉ nằm trên '
                                  'máy này; gỡ app hoặc mất máy là mất dữ liệu.', 'You haven\'t made a backup yet. Your data only lives on ' 'this phone; uninstalling or losing it means losing your data.')
                              : tr('Lần sao lưu gần nhất: ${shortDate(last)}.', 'Last backup: ${shortDate(last)}.'),
                          style: const TextStyle(fontSize: 13, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GroupCard(children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconAvatar(icon: 'savings', color: 'green'),
                  title: Text(tr('Tạo bản sao lưu', 'Create backup')),
                  subtitle: Text(
                      tr('File được khóa bằng mật khẩu. Lưu vào Drive, Zalo hoặc '
                      'máy tính.', 'The file is locked with a password. Save it to Drive, a chat app or ' 'your computer.')),
                  onTap: _backup,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconAvatar(icon: 'transfer', color: 'blue'),
                  title: Text(tr('Khôi phục từ file', 'Restore from file')),
                  subtitle: Text(
                      tr('Thay toàn bộ dữ liệu trên máy bằng dữ liệu trong file.', 'Replace all data on this phone with the data in the file.')),
                  onTap: _restore,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconAvatar(icon: 'bills', color: 'purple'),
                  title: Text(tr('Xuất giao dịch ra CSV', 'Export transactions to CSV')),
                  subtitle: Text(
                      tr('Mở được bằng Excel hoặc Google Sheets. File không mã hóa.', 'Opens in Excel or Google Sheets. The file is not encrypted.')),
                  onTap: _exportCsv,
                ),
              ]),
              const SizedBox(height: 16),
              Text(
                tr('Quên mật khẩu thì không ai mở lại được file sao lưu, kể cả '
                'nhà phát triển. Hãy ghi mật khẩu ở nơi an toàn.', 'If you forget the password, nobody can open the backup, not even ' 'the developer. Keep the password somewhere safe.'),
                style: TichiText.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hỏi mật khẩu. [confirm] true thì bắt nhập hai lần (khi tạo sao lưu).
/// Chọn file sao lưu, hỏi mật khẩu, cho xem trước rồi khôi phục. Dùng ở màn
/// Sao lưu và ở màn chào mừng. Trả về true nếu đã khôi phục xong.
Future<bool> restoreFromBackupFile(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  void snack(String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message)));

  final Uint8List bytes;
  try {
    final file = await FilePicker.pickFile();
    if (file == null) return false;
    bytes = await file.readAsBytes();
  } catch (_) {
    snack(tr('Không mở được file.', 'Couldn\'t open the file.'));
    return false;
  }
  if (!context.mounted) return false;
  final password = await _askPassword(context, confirm: false);
  if (password == null || !context.mounted) return false;
  final service = BackupService(store.core);
  try {
    final temp = await getTemporaryDirectory();
    final plan = await service.openBackup(bytes, password, temp);
    if (!context.mounted) {
      service.discard(plan);
      return false;
    }
    final p = plan.preview;
    final ok = await confirmAction(
      context,
      title: tr('Khôi phục bản sao lưu?', 'Restore this backup?'),
      message: tr('Bản sao lưu có ${p.walletCount} ví, ${p.transactionCount} '
          'giao dịch, ${p.goalCount} mục tiêu'
          '${p.latestTransactionDate == null ? '' : ', giao dịch mới nhất ngày ${shortDate(p.latestTransactionDate!)}'}.\n\n'
          'Toàn bộ dữ liệu đang có trên máy sẽ được thay bằng dữ liệu này.', 'The backup has ${p.walletCount} wallets, ${p.transactionCount} ' 'transactions, ${p.goalCount} goals' '${p.latestTransactionDate == null ? '' : ', latest transaction on ${shortDate(p.latestTransactionDate!)}'}.\n\n' 'All data currently on this phone will be replaced with it.'),
      confirmLabel: tr('Khôi phục', 'Restore'),
    );
    if (!ok) {
      service.discard(plan);
      return false;
    }
    service.applyRestore(plan);
    store.reloadAll();
    snack(tr('Đã khôi phục dữ liệu.', 'Data restored.'));
    return true;
  } on FinanceException catch (error) {
    snack(friendlyError(error));
  } catch (_) {
    snack(tr('Không khôi phục được. Dữ liệu hiện tại vẫn giữ nguyên.', 'Couldn\'t restore. Your current data is unchanged.'));
  }
  return false;
}

Future<String?> _askPassword(BuildContext context,
    {required bool confirm}) async {
  final first = TextEditingController();
  final second = TextEditingController();
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(confirm ? tr('Đặt mật khẩu cho file', 'Set a password for the file') : tr('Nhập mật khẩu của file', 'Enter the file\'s password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('backup-password'),
              controller: first,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('Mật khẩu', 'Password')),
            ),
            if (confirm)
              TextField(
                controller: second,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('Nhập lại mật khẩu', 'Repeat password')),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!,
                    style: TextStyle(
                        color: TichiColors.danger, fontSize: 13)),
              ),
            if (confirm)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    tr('Quên mật khẩu là không mở được file. Tichi không lưu mật '
                    'khẩu này.', 'If you forget the password, the file can\'t be opened. Tichi ' 'doesn\'t store it.'),
                    style: TichiText.label),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              if (first.text.length < minPasswordLength) {
                setState(() => error =
                    tr('Mật khẩu cần ít nhất $minPasswordLength ký tự.', 'The password needs at least $minPasswordLength characters.'));
                return;
              }
              if (confirm && first.text != second.text) {
                setState(() => error = tr('Hai lần nhập không giống nhau.', 'The two passwords don\'t match.'));
                return;
              }
              Navigator.pop(dialogContext, first.text);
            },
            child: Text(tr('Tiếp tục', 'Continue')),
          ),
        ],
      ),
    ),
  );
  return result;
}

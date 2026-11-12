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
        dialogTitle: 'Lưu file sao lưu',
        fileName: 'tichi-saoluu-${_stamp()}.tichi',
        bytes: bytes,
      );
      if (saved != null) {
        store.core.setSetting('last_backup_at', dateKey(DateTime.now()));
        store.reloadAll();
        _snack('Đã lưu file sao lưu. Hãy giữ file và mật khẩu cẩn thận.');
      }
    } on FinanceException catch (error) {
      _snack(friendlyError(error));
    } catch (_) {
      _snack('Không lưu được file sao lưu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final store = StoreScope.read(context);
    final PlatformFile? file;
    final Uint8List bytes;
    try {
      file = await FilePicker.pickFile();
      if (file == null) return;
      bytes = await file.readAsBytes();
    } catch (_) {
      _snack('Không mở được file.');
      return;
    }
    if (!mounted) return;
    final password = await _askPassword(context, confirm: false);
    if (password == null) return;
    setState(() => _busy = true);
    final service = BackupService(store.core);
    try {
      final temp = await getTemporaryDirectory();
      final plan = await service.openBackup(bytes, password, temp);
      if (!mounted) {
        service.discard(plan);
        return;
      }
      final p = plan.preview;
      final ok = await confirmAction(
        context,
        title: 'Khôi phục bản sao lưu?',
        message: 'Bản sao lưu có ${p.walletCount} ví, ${p.transactionCount} '
            'giao dịch, ${p.goalCount} mục tiêu'
            '${p.latestTransactionDate == null ? '' : ', giao dịch mới nhất ngày ${shortDate(p.latestTransactionDate!)}'}.\n\n'
            'Toàn bộ dữ liệu đang có trên máy sẽ được thay bằng dữ liệu này.',
        confirmLabel: 'Khôi phục',
      );
      if (!ok) {
        service.discard(plan);
        return;
      }
      service.applyRestore(plan);
      store.reloadAll();
      _snack('Đã khôi phục dữ liệu.');
    } on FinanceException catch (error) {
      _snack(friendlyError(error));
    } catch (_) {
      _snack('Không khôi phục được. Dữ liệu hiện tại vẫn giữ nguyên.');
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
        dialogTitle: 'Lưu file CSV',
        fileName: 'tichi-giaodich-${_stamp()}.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (saved != null) _snack('Đã xuất danh sách giao dịch.');
    } catch (_) {
      _snack('Không xuất được file CSV.');
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
        title: const Text('Sao lưu và khôi phục',
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
                              ? 'Bạn chưa sao lưu lần nào. Dữ liệu chỉ nằm trên '
                                  'máy này; gỡ app hoặc mất máy là mất dữ liệu.'
                              : 'Lần sao lưu gần nhất: ${shortDate(last)}.',
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
                  title: const Text('Tạo bản sao lưu'),
                  subtitle: const Text(
                      'File được khóa bằng mật khẩu. Lưu vào Drive, Zalo hoặc '
                      'máy tính.'),
                  onTap: _backup,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconAvatar(icon: 'transfer', color: 'blue'),
                  title: const Text('Khôi phục từ file'),
                  subtitle: const Text(
                      'Thay toàn bộ dữ liệu trên máy bằng dữ liệu trong file.'),
                  onTap: _restore,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconAvatar(icon: 'bills', color: 'purple'),
                  title: const Text('Xuất giao dịch ra CSV'),
                  subtitle: const Text(
                      'Mở được bằng Excel hoặc Google Sheets. File không mã hóa.'),
                  onTap: _exportCsv,
                ),
              ]),
              const SizedBox(height: 16),
              Text(
                'Quên mật khẩu thì không ai mở lại được file sao lưu, kể cả '
                'nhà phát triển. Hãy ghi mật khẩu ở nơi an toàn.',
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
Future<String?> _askPassword(BuildContext context,
    {required bool confirm}) async {
  final first = TextEditingController();
  final second = TextEditingController();
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(confirm ? 'Đặt mật khẩu cho file' : 'Nhập mật khẩu của file'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('backup-password'),
              controller: first,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
            ),
            if (confirm)
              TextField(
                controller: second,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
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
                    'Quên mật khẩu là không mở được file. Tichi không lưu mật '
                    'khẩu này.',
                    style: TichiText.label),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              if (first.text.length < minPasswordLength) {
                setState(() => error =
                    'Mật khẩu cần ít nhất $minPasswordLength ký tự.');
                return;
              }
              if (confirm && first.text != second.text) {
                setState(() => error = 'Hai lần nhập không giống nhau.');
                return;
              }
              Navigator.pop(dialogContext, first.text);
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    ),
  );
  return result;
}

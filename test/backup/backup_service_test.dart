import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tichi/core/backup/backup_service.dart';
import 'package:tichi/core/finance/finance_core.dart';
import 'package:tichi/core/savings/savings_center.dart';

Matcher throwsFinance(String code) => throwsA(
    isA<FinanceException>().having((e) => e.code, 'code', code));

void main() {
  late Directory temp;
  late FinanceCore source;
  late SavingsCenter savings;
  late String bank;
  late String vault;
  late String goal;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('tichi_backup_test');
    source = FinanceCore.inMemory();
    savings = SavingsCenter(source);
    bank = source.createWallet(
        name: 'Ngân hàng',
        type: 'BANK',
        currencyCode: 'VND',
        openingBalanceMinor: 20000000);
    vault = source.createWallet(
        name: 'Ví tiết kiệm', type: 'SAVINGS', currencyCode: 'VND');
    final food = source.createCategory(name: 'Ăn uống', type: 'EXPENSE');
    source.addExpense(
        requestId: 'lunch',
        walletId: bank,
        amountMinor: 55000,
        date: '2026-11-10',
        categoryId: food,
        note: 'Cơm, "tấm"');
    goal = savings.createGoal(
        name: 'Du lịch',
        targetMinor: 30000000,
        savingsWalletId: vault,
        startDate: '2026-11-01',
        targetDate: '2027-06-30');
    savings.contribute(
        requestId: 'save',
        goalId: goal,
        fromWalletId: bank,
        amountMinor: 2000000,
        date: '2026-11-11');
    source.setSetting('rate_usd_vnd', '26300');
  });

  tearDown(() {
    source.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  BackupService service(FinanceCore core) =>
      BackupService(core, iterations: 1000);

  test('sao lưu rồi khôi phục sang máy khác giữ nguyên số liệu (kiểm thử 15)',
      () async {
    final bytes = await service(source).createBackup('mat-khau-1', temp);

    final target = FinanceCore.inMemory();
    target.createWallet(name: 'Ví cũ', type: 'CASH', currencyCode: 'VND');
    final backup = service(target);
    final plan = await backup.openBackup(bytes, 'mat-khau-1', temp);
    expect(plan.preview.walletCount, 2);
    expect(plan.preview.transactionCount, 2);
    expect(plan.preview.goalCount, 1);
    expect(plan.preview.latestTransactionDate, '2026-11-11');

    backup.applyRestore(plan);
    expect(target.wallets().map((w) => w.name), ['Ngân hàng', 'Ví tiết kiệm']);
    expect(target.walletBalance(bank), 17945000);
    expect(target.walletBalance(vault), 2000000);
    final restoredSavings = SavingsCenter(target);
    expect(restoredSavings.savedMinor(goal), 2000000);
    expect(restoredSavings.unallocatedMinor(vault), 0);
    expect(target.getSetting('rate_usd_vnd'), '26300');
    // Không còn file tạm nào sau khi khôi phục.
    expect(temp.listSync(), isEmpty);
    target.close();
  });

  test('sai mật khẩu thì báo lỗi, không thay đổi gì', () async {
    final bytes = await service(source).createBackup('mat-khau-1', temp);
    final target = FinanceCore.inMemory();
    final cash =
        target.createWallet(name: 'Tiền mặt', type: 'CASH', currencyCode: 'VND');
    await expectLater(service(target).openBackup(bytes, 'sai-mat-khau', temp),
        throwsFinance('wrong_password'));
    expect(target.wallets().single.id, cash);
    target.close();
  });

  test('file bị sửa một byte thì bị phát hiện', () async {
    final bytes = await service(source).createBackup('mat-khau-1', temp);
    final tampered = Uint8List.fromList(bytes);
    tampered[tampered.length - 10] ^= 0xFF;
    await expectLater(service(source).openBackup(tampered, 'mat-khau-1', temp),
        throwsFinance('wrong_password'));
  });

  test('file không phải của Tichi thì bị từ chối', () async {
    final junk = Uint8List.fromList(List<int>.filled(200, 7));
    await expectLater(service(source).openBackup(junk, 'mat-khau-1', temp),
        throwsFinance('backup_invalid'));
  });

  test('mật khẩu quá ngắn thì không cho sao lưu', () async {
    await expectLater(service(source).createBackup('123', temp),
        throwsFinance('weak_password'));
  });

  test('hai lần sao lưu cùng mật khẩu cho ra hai file khác nhau', () async {
    final first = await service(source).createBackup('mat-khau-1', temp);
    final second = await service(source).createBackup('mat-khau-1', temp);
    expect(first, isNot(equals(second)));
  });

  test('bỏ khôi phục thì dữ liệu giữ nguyên và xóa file tạm', () async {
    final bytes = await service(source).createBackup('mat-khau-1', temp);
    final target = FinanceCore.inMemory();
    target.createWallet(name: 'Tiền mặt', type: 'CASH', currencyCode: 'VND');
    final backup = service(target);
    final plan = await backup.openBackup(bytes, 'mat-khau-1', temp);
    backup.discard(plan);
    expect(target.wallets().single.name, 'Tiền mặt');
    expect(temp.listSync(), isEmpty);
    target.close();
  });

  test('xuất CSV: cũ trước, có BOM, ô có dấu phẩy và ngoặc kép được bọc',
      () {
    final csv = service(source).exportCsv();
    final lines = csv.trim().split('\n');
    expect(csv.startsWith('﻿Ngày,Loại,Số tiền'), isTrue);
    expect(lines.length, 3);
    expect(lines[1], '2026-11-10,Chi,55000,VND,Ăn uống,Ngân hàng,,"Cơm, ""tấm"""');
    expect(lines[2],
        '2026-11-11,Tiết kiệm,2000000,VND,,Ngân hàng,Ví tiết kiệm,');
  });

  test('sửa số dư ban đầu của ví', () {
    source.setOpeningBalance(bank, 25000000);
    expect(source.walletBalance(bank), 22945000);
    expect(source.openingBalance(bank), 25000000);
    expect(() => source.setOpeningBalance(bank, -1),
        throwsFinance('invalid_amount'));
  });
}

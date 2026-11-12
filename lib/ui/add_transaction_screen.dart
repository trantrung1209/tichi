/// Thêm giao dịch: chọn Chi, Thu hoặc Chuyển ví, nhập số tiền, chọn danh
/// mục, ví và ngày, rồi Lưu.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import 'icons.dart';
import 'widgets.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amount = TextEditingController();
  final _received = TextEditingController();
  final _note = TextEditingController();

  String _type = 'EXPENSE';
  String? _categoryId;
  String? _walletId;
  String? _toWalletId;
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  /// Tạo một lần khi mở màn hình. Bấm Lưu nhiều lần vẫn chỉ tạo một giao dịch.
  late final String _requestId;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    _requestId = store.newRequestId();
    final wallets = store.spendingWallets();
    if (wallets.isNotEmpty) _walletId = wallets.first.id;
    if (wallets.length > 1) _toWalletId = wallets[1].id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _note.dispose();
    super.dispose();
  }

  WalletInfo? _find(List<WalletInfo> wallets, String? id) {
    for (final wallet in wallets) {
      if (wallet.id == id) return wallet;
    }
    return null;
  }

  Future<void> _chooseWallet(List<WalletInfo> wallets,
      {required bool target}) async {
    final picked = await pickWallet(context, wallets,
        selectedId: target ? _toWalletId : _walletId,
        title: target ? 'Đến ví' : (_type == 'TRANSFER' ? 'Từ ví' : 'Ví'));
    if (picked == null) return;
    setState(() {
      if (target) {
        _toWalletId = picked;
      } else {
        _walletId = picked;
      }
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _fail(String message) => setState(() {
        _saving = false;
        _error = message;
      });

  void _save(List<WalletInfo> wallets) {
    final store = StoreScope.read(context);
    final from = _find(wallets, _walletId);
    if (from == null) return _fail('Chọn một ví.');
    final amount = parseMinor(_amount.text, from.currencyCode);
    if (amount == null || amount <= 0) return _fail('Nhập số tiền lớn hơn 0.');
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final date = dateKey(_date);
    setState(() => _saving = true);
    try {
      switch (_type) {
        case 'INCOME':
          store.addIncome(
              requestId: _requestId,
              walletId: from.id,
              amountMinor: amount,
              date: date,
              categoryId: _categoryId,
              note: note);
        case 'EXPENSE':
          store.addExpense(
              requestId: _requestId,
              walletId: from.id,
              amountMinor: amount,
              date: date,
              categoryId: _categoryId,
              note: note);
        default:
          final to = _find(wallets, _toWalletId);
          if (to == null || to.id == from.id) {
            return _fail('Chọn ví nhận khác ví chuyển.');
          }
          int? received;
          if (to.currencyCode != from.currencyCode) {
            received = parseMinor(_received.text, to.currencyCode);
            if (received == null || received <= 0) {
              return _fail('Nhập số tiền ví nhận được.');
            }
          }
          store.transfer(
              requestId: _requestId,
              fromWalletId: from.id,
              toWalletId: to.id,
              amountMinor: amount,
              destinationAmountMinor: received,
              date: date,
              note: note);
      }
    } on FinanceException catch (error) {
      return _fail(friendlyError(error));
    }
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final wallets = store.spendingWallets();
    final from = _find(wallets, _walletId);
    final to = _find(wallets, _toWalletId);
    final currency = from?.currencyCode ?? store.baseCurrency;
    final isTransfer = _type == 'TRANSFER';
    final needsReceived = isTransfer &&
        from != null &&
        to != null &&
        from.currencyCode != to.currencyCode;
    final categories =
        isTransfer ? const <CategoryInfo>[] : store.categories(_type);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Thêm giao dịch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 'EXPENSE',
                    label: Text('Chi', key: Key('type-EXPENSE'))),
                ButtonSegment(
                    value: 'INCOME',
                    label: Text('Thu', key: Key('type-INCOME'))),
                ButtonSegment(
                    value: 'TRANSFER',
                    label: Text('Chuyển ví', key: Key('type-TRANSFER'))),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() {
                _type = selection.first;
                _categoryId = null;
                _error = null;
              }),
            ),
            const SizedBox(height: 20),
            AmountInput(
              fieldKey: const Key('amount-field'),
              controller: _amount,
              currency: currency,
              autofocus: true,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            if (!isTransfer) ...[
              const FieldLabel('Danh mục'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      avatar: Icon(iconFor(category.icon),
                          size: 18,
                          color: category.id == _categoryId
                              ? tintFor(category.color).foreground
                              : TichiColors.muted),
                      label: Text(category.name),
                      selected: category.id == _categoryId,
                      selectedColor: tintFor(category.color).background,
                      showCheckmark: false,
                      onSelected: (selected) => setState(
                          () => _categoryId = selected ? category.id : null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            GroupCard(children: [
              PickerRow(
                label: isTransfer ? 'Từ ví' : 'Ví',
                value: from?.name ?? 'Chọn ví',
                leading: from == null
                    ? null
                    : IconAvatar(icon: from.icon, color: from.color, size: 28),
                onTap: () => _chooseWallet(wallets, target: false),
              ),
              if (isTransfer)
                PickerRow(
                  label: 'Đến ví',
                  value: to?.name ?? 'Chọn ví',
                  leading: to == null
                      ? null
                      : IconAvatar(icon: to.icon, color: to.color, size: 28),
                  onTap: () => _chooseWallet(wallets, target: true),
                ),
              PickerRow(
                label: 'Ngày',
                value: dayLabel(dateKey(_date), DateTime.now()),
                onTap: _pickDate,
              ),
            ]),
            if (needsReceived && to != null) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('received-field'),
                controller: _received,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: to.currencyCode == 'USD'),
                inputFormatters: moneyFormatters(to.currencyCode),
                decoration: InputDecoration(
                  labelText: 'Số tiền ví ${to.name} nhận được',
                  suffixText: to.currencyCode == 'USD' ? 'USD' : '₫',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration:
                  const InputDecoration(labelText: 'Ghi chú (không bắt buộc)'),
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save-button'),
              onPressed: _saving ? null : () => _save(wallets),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

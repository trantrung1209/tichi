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
import '../core/l10n.dart';

/// Mở một giao dịch để sửa. Lần góp, rút tiết kiệm không sửa được: báo cách
/// làm thay vì mở màn hình.
void openTransaction(BuildContext context, TransactionView tx) {
  if (tx.isSavingsMove) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(tr('Lần góp hoặc rút tiết kiệm không sửa được. Vuốt '
              'sang trái để xóa rồi làm lại trong mục Tiết kiệm.', 'Savings deposits and withdrawals can\'t be edited. Swipe ' 'left to delete, then redo it in Savings.'))));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AddTransactionScreen(editing: tx)));
}

class AddTransactionScreen extends StatefulWidget {
  /// [editing] có giá trị thì màn hình dùng để sửa giao dịch đó.
  const AddTransactionScreen({super.key, this.editing});

  final TransactionView? editing;

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
    final editing = widget.editing;
    if (editing != null) {
      _type = editing.type;
      _walletId = editing.type == 'INCOME'
          ? editing.destinationWalletId
          : editing.sourceWalletId;
      _toWalletId =
          editing.type == 'TRANSFER' ? editing.destinationWalletId : null;
      _categoryId = editing.categoryId;
      _date = DateTime.tryParse(editing.date) ?? DateTime.now();
      _amount.text = amountText(editing.amountMinor, editing.currency);
      final received = editing.destinationAmountMinor;
      if (editing.type == 'TRANSFER' &&
          received != null &&
          editing.destinationCurrency != editing.sourceCurrency) {
        _received.text = amountText(received, editing.destinationCurrency!);
      }
      _note.text = editing.note ?? '';
      return;
    }
    final wallets = store.spendingWallets();
    if (wallets.isNotEmpty) _walletId = wallets.first.id;
    if (wallets.length > 1) _toWalletId = wallets[1].id;
  }

  bool get _isEdit => widget.editing != null;

  Future<void> _delete() async {
    final tx = widget.editing!;
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    final ok = await confirmAction(context,
        title: tr('Xóa giao dịch này?', 'Delete this transaction?'),
        message: tr('Số dư các ví và báo cáo sẽ tính lại ngay.', 'Wallet balances and reports will update right away.'),
        confirmLabel: tr('Xóa', 'Delete'));
    if (!ok) return;
    try {
      store.deleteTransaction(tx.id);
    } on FinanceException catch (error) {
      return _fail(friendlyError(error));
    }
    HapticFeedback.mediumImpact();
    navigator.pop();
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
        title: target ? tr('Đến ví', 'To wallet') : (_type == 'TRANSFER' ? tr('Từ ví', 'From wallet') : tr('Ví', 'Wallet')));
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
    if (from == null) return _fail(tr('Chọn một ví.', 'Choose a wallet.'));
    final amount = parseMinor(_amount.text, from.currencyCode);
    if (amount == null || amount <= 0) return _fail(tr('Nhập số tiền lớn hơn 0.', 'Enter an amount greater than 0.'));
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final date = dateKey(_date);
    setState(() => _saving = true);
    try {
      final editing = widget.editing;
      if (editing != null) {
        int? received;
        String? toId;
        if (_type == 'TRANSFER') {
          final to = _find(wallets, _toWalletId);
          if (to == null || to.id == from.id) {
            return _fail(tr('Chọn ví nhận khác ví chuyển.', 'Choose a different receiving wallet.'));
          }
          toId = to.id;
          if (to.currencyCode != from.currencyCode) {
            received = parseMinor(_received.text, to.currencyCode);
            if (received == null || received <= 0) {
              return _fail(tr('Nhập số tiền ví nhận được.', 'Enter the amount the wallet receives.'));
            }
          }
        }
        store.updateTransaction(editing.id,
            walletId: from.id,
            toWalletId: toId,
            amountMinor: amount,
            destinationAmountMinor: received,
            date: date,
            categoryId: _type == 'TRANSFER' ? null : _categoryId,
            note: note);
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        return;
      }
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
            return _fail(tr('Chọn ví nhận khác ví chuyển.', 'Choose a different receiving wallet.'));
          }
          int? received;
          if (to.currencyCode != from.currencyCode) {
            received = parseMinor(_received.text, to.currencyCode);
            if (received == null || received <= 0) {
              return _fail(tr('Nhập số tiền ví nhận được.', 'Enter the amount the wallet receives.'));
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
          tooltip: tr('Đóng', 'Close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEdit ? tr('Sửa giao dịch', 'Edit transaction') : tr('Thêm giao dịch', 'Add transaction'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (_isEdit)
            IconButton(
              key: const Key('delete-transaction'),
              tooltip: tr('Xóa giao dịch', 'Delete transaction'),
              icon: Icon(Icons.delete_outline, color: TichiColors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: 'EXPENSE',
                    label: Text(tr('Chi', 'Expense'), key: Key('type-EXPENSE'))),
                ButtonSegment(
                    value: 'INCOME',
                    label: Text(tr('Thu', 'Income'), key: Key('type-INCOME'))),
                ButtonSegment(
                    value: 'TRANSFER',
                    label: Text(tr('Chuyển ví', 'Transfer'), key: Key('type-TRANSFER'))),
              ],
              selected: {_type},
              // Khi sửa thì không đổi loại giao dịch được.
              onSelectionChanged: _isEdit
                  ? null
                  : (selection) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _type = selection.first;
                        _categoryId = null;
                        _error = null;
                      });
                    },
            ),
            const SizedBox(height: 20),
            AmountInput(
              fieldKey: const Key('amount-field'),
              controller: _amount,
              currency: currency,
              autofocus: !_isEdit,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            if (!isTransfer) ...[
              FieldLabel(tr('Danh mục', 'Category')),
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
                      onSelected: (selected) {
                        HapticFeedback.selectionClick();
                        setState(
                            () => _categoryId = selected ? category.id : null);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            GroupCard(children: [
              PickerRow(
                label: isTransfer ? tr('Từ ví', 'From wallet') : tr('Ví', 'Wallet'),
                value: from?.name ?? tr('Chọn ví', 'Choose wallet'),
                leading: from == null
                    ? null
                    : IconAvatar(icon: from.icon, color: from.color, size: 28),
                onTap: () => _chooseWallet(wallets, target: false),
              ),
              if (isTransfer)
                PickerRow(
                  label: tr('Đến ví', 'To wallet'),
                  value: to?.name ?? tr('Chọn ví', 'Choose wallet'),
                  leading: to == null
                      ? null
                      : IconAvatar(icon: to.icon, color: to.color, size: 28),
                  onTap: () => _chooseWallet(wallets, target: true),
                ),
              PickerRow(
                label: tr('Ngày', 'Date'),
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
                  labelText: tr('Số tiền ví ${to.name} nhận được', 'Amount ${to.name} receives'),
                  suffixText: to.currencyCode == 'USD' ? 'USD' : '₫',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration:
                  InputDecoration(labelText: tr('Ghi chú (không bắt buộc)', 'Note (optional)')),
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save-button'),
              onPressed: _saving ? null : () => _save(wallets),
              child: Text(tr('Lưu', 'Save')),
            ),
          ],
        ),
      ),
    );
  }
}

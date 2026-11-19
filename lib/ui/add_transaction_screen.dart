/// Thêm giao dịch kiểu nhập nhanh: số tiền và bàn phím máy tính luôn ở dưới
/// ngón cái, danh mục và ví nằm ngay phía trên nên không bị che. Ca thường
/// gặp chỉ cần gõ số, chạm danh mục, bấm Lưu.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/calculator.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import '../core/l10n.dart';
import 'icons.dart';
import 'keypad.dart';
import 'widgets.dart';

/// Mở một giao dịch để sửa. Lần góp, rút tiết kiệm không sửa được: báo cách
/// làm thay vì mở màn hình.
void openTransaction(BuildContext context, TransactionView tx) {
  if (tx.isSavingsMove) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(tr(
              'Lần góp hoặc rút tiết kiệm không sửa được. Vuốt '
                  'sang trái để xóa rồi làm lại trong mục Tiết kiệm.',
              'Savings deposits and withdrawals can\'t be edited. Swipe '
                  'left to delete, then redo it in Savings.'))));
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
  late final AmountCalculator _calc;
  String _note = '';
  String _received = '';

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
    // Thông báo "Đã ghi … · Hoàn tác" của lần lưu trước nằm đè lên bàn phím
    // và dễ bị chạm nhầm thành Hoàn tác: gỡ nó ngay khi mở màn hình này.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    });
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
      _calc = AmountCalculator(editing.currency)..setMinor(editing.amountMinor);
      final received = editing.destinationAmountMinor;
      if (editing.type == 'TRANSFER' &&
          received != null &&
          editing.destinationCurrency != editing.sourceCurrency) {
        _received = amountText(received, editing.destinationCurrency!);
      }
      _note = editing.note ?? '';
      return;
    }
    _walletId = store.suggestedWalletId(_type);
    _calc = AmountCalculator(_currencyOf(store.spendingWallets(), _walletId) ??
        store.baseCurrency);
    _pickDefaultTarget(store.spendingWallets());
  }

  bool get _isEdit => widget.editing != null;

  String? _currencyOf(List<WalletInfo> wallets, String? id) =>
      _find(wallets, id)?.currencyCode;

  WalletInfo? _find(List<WalletInfo> wallets, String? id) {
    for (final wallet in wallets) {
      if (wallet.id == id) return wallet;
    }
    return null;
  }

  /// Chọn sẵn ví nhận cho Chuyển ví: ví đầu tiên khác ví chuyển.
  void _pickDefaultTarget(List<WalletInfo> wallets) {
    if (_toWalletId != null && _toWalletId != _walletId) return;
    _toWalletId = null;
    for (final wallet in wallets) {
      if (wallet.id != _walletId) {
        _toWalletId = wallet.id;
        return;
      }
    }
  }

  void _changed() => setState(() => _error = null);

  void _setType(String type) {
    final store = StoreScope.read(context);
    HapticFeedback.selectionClick();
    setState(() {
      _type = type;
      _categoryId = null;
      _error = null;
      _walletId = store.suggestedWalletId(type);
      final wallets = store.spendingWallets();
      _calc.currency = _currencyOf(wallets, _walletId) ?? _calc.currency;
      _pickDefaultTarget(wallets);
    });
  }

  Future<void> _delete() async {
    final tx = widget.editing!;
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    final ok = await confirmAction(context,
        title: tr('Xóa giao dịch này?', 'Delete this transaction?'),
        message: tr('Số dư các ví và báo cáo sẽ tính lại ngay.',
            'Wallet balances and reports will update right away.'),
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

  Future<void> _chooseWallet(List<WalletInfo> wallets,
      {required bool target}) async {
    final picked = await pickWallet(context, wallets,
        selectedId: target ? _toWalletId : _walletId,
        title: target
            ? tr('Đến ví', 'To wallet')
            : (_type == 'TRANSFER'
                ? tr('Từ ví', 'From wallet')
                : tr('Ví', 'Wallet')));
    if (picked == null) return;
    setState(() {
      if (target) {
        _toWalletId = picked;
      } else {
        _walletId = picked;
        final currency = _currencyOf(wallets, picked);
        if (currency != null && currency != _calc.currency) {
          // Đổi loại tiền thì số đã gõ không còn đúng nghĩa: xóa để gõ lại.
          _calc
            ..currency = currency
            ..clear();
        }
        _pickDefaultTarget(wallets);
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

  /// Hộp nhập một dòng chữ; trả về null nếu người dùng bấm Hủy.
  Future<String?> _askText({
    required String title,
    required String initial,
    Key? fieldKey,
    String? currency,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: fieldKey,
          controller: controller,
          autofocus: true,
          keyboardType: currency == null
              ? TextInputType.text
              : TextInputType.numberWithOptions(decimal: currency == 'USD'),
          inputFormatters:
              currency == null ? null : moneyFormatters(currency),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Hủy', 'Cancel'))),
          TextButton(
              key: const Key('text-dialog-ok'),
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(tr('Xong', 'Done'))),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _editNote() async {
    final value = await _askText(
        title: tr('Ghi chú', 'Note'),
        initial: _note,
        fieldKey: const Key('note-field'));
    if (value != null) setState(() => _note = value.trim());
  }

  Future<void> _editReceived(WalletInfo to) async {
    final value = await _askText(
      title: tr('Ví ${to.name} nhận được', '${to.name} receives'),
      initial: _received,
      fieldKey: const Key('received-field'),
      currency: to.currencyCode,
    );
    if (value != null) setState(() => _received = value);
  }

  void _fail(String message) => setState(() {
        _saving = false;
        _error = message;
      });

  String _calcError(String code) => switch (code) {
        'divide_by_zero' =>
          tr('Không chia được cho 0.', 'Can\'t divide by 0.'),
        _ => tr('Số tiền quá lớn.', 'The amount is too large.'),
      };

  void _save(List<WalletInfo> wallets, List<CategoryInfo> categories) {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final from = _find(wallets, _walletId);
    if (from == null) return _fail(tr('Chọn một ví.', 'Choose a wallet.'));
    final result = _calc.evaluate();
    if (result.error != null) return _fail(_calcError(result.error!));
    final amount = result.value!;
    if (amount <= 0) {
      return _fail(tr('Số tiền phải lớn hơn 0.', 'The amount must be more than 0.'));
    }
    final note = _note.isEmpty ? null : _note;
    final date = dateKey(_date);
    String? toId;
    int? received;
    if (_type == 'TRANSFER') {
      final to = _find(wallets, _toWalletId);
      if (to == null || to.id == from.id) {
        return _fail(tr('Chọn ví nhận khác ví chuyển.',
            'Choose a different receiving wallet.'));
      }
      toId = to.id;
      if (to.currencyCode != from.currencyCode) {
        received = parseMinor(_received, to.currencyCode);
        if (received == null || received <= 0) {
          return _fail(tr('Nhập số tiền ví nhận được.',
              'Enter the amount the wallet receives.'));
        }
      }
    }
    setState(() => _saving = true);
    final String id;
    try {
      final editing = widget.editing;
      if (editing != null) {
        store.updateTransaction(editing.id,
            walletId: from.id,
            toWalletId: toId,
            amountMinor: amount,
            destinationAmountMinor: received,
            date: date,
            categoryId: _type == 'TRANSFER' ? null : _categoryId,
            note: note);
        HapticFeedback.lightImpact();
        navigator.pop();
        return;
      }
      id = switch (_type) {
        'INCOME' => store.addIncome(
            requestId: _requestId,
            walletId: from.id,
            amountMinor: amount,
            date: date,
            categoryId: _categoryId,
            note: note),
        'EXPENSE' => store.addExpense(
            requestId: _requestId,
            walletId: from.id,
            amountMinor: amount,
            date: date,
            categoryId: _categoryId,
            note: note),
        _ => store.transfer(
            requestId: _requestId,
            fromWalletId: from.id,
            toWalletId: toId!,
            amountMinor: amount,
            destinationAmountMinor: received,
            date: date,
            note: note),
      };
    } on FinanceException catch (error) {
      return _fail(friendlyError(error));
    }
    HapticFeedback.lightImpact();
    String? categoryName;
    for (final c in categories) {
      if (c.id == _categoryId) categoryName = c.name;
    }
    final what = categoryName ??
        (_type == 'TRANSFER' ? tr('Chuyển ví', 'Transfer') : null);
    final shown = formatMinor(amount, from.currencyCode);
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        key: const Key('saved-snackbar'),
        duration: const Duration(seconds: 4),
        content: Text(what == null
            ? tr('Đã ghi $shown', 'Saved $shown')
            : tr('Đã ghi $shown · $what', 'Saved $shown · $what')),
        action: SnackBarAction(
          label: tr('Hoàn tác', 'Undo'),
          onPressed: () {
            try {
              store.deleteTransaction(id);
            } on FinanceException {
              // Giao dịch đã bị xóa ở nơi khác: không cần làm gì thêm.
            }
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final wallets = store.spendingWallets();
    final from = _find(wallets, _walletId);
    final to = _find(wallets, _toWalletId);
    final isTransfer = _type == 'TRANSFER';
    final needsReceived = isTransfer &&
        from != null &&
        to != null &&
        from.currencyCode != to.currencyCode;
    final categories = isTransfer
        ? const <CategoryInfo>[]
        : store.categoriesByUsage(_type);
    final frequent =
        store.frequentAmounts(_type, _categoryId, _calc.currency);
    final usd = _calc.currency == 'USD';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(children: [
          // Thanh trên: đóng, chọn loại, xóa khi đang sửa.
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(children: [
              IconButton(
                tooltip: tr('Đóng', 'Close'),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                        value: 'EXPENSE',
                        label:
                            Text(tr('Chi', 'Expense'), key: const Key('type-EXPENSE'))),
                    ButtonSegment(
                        value: 'INCOME',
                        label:
                            Text(tr('Thu', 'Income'), key: const Key('type-INCOME'))),
                    ButtonSegment(
                        value: 'TRANSFER',
                        label: Text(tr('Chuyển', 'Transfer'),
                            key: const Key('type-TRANSFER'))),
                  ],
                  selected: {_type},
                  // Khi sửa thì không đổi loại giao dịch được.
                  onSelectionChanged:
                      _isEdit ? null : (selection) => _setType(selection.first),
                ),
              ),
              if (_isEdit)
                IconButton(
                  key: const Key('delete-transaction'),
                  tooltip: tr('Xóa giao dịch', 'Delete transaction'),
                  icon: Icon(Icons.delete_outline, color: TichiColors.danger),
                  onPressed: _delete,
                )
              else
                const SizedBox(width: 48),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEdit
                        ? tr('Sửa giao dịch', 'Edit transaction')
                        : tr('Thêm giao dịch', 'Add transaction'),
                    textAlign: TextAlign.center,
                    style: TichiText.caption,
                  ),
                  const SizedBox(height: 8),
                  _AmountDisplay(
                    expression: _calc.expressionText,
                    amount: _calc.displayText,
                    symbol: usd ? 'USD' : '₫',
                  ),
                  const SizedBox(height: 12),
                  _ContextLine(
                    isTransfer: isTransfer,
                    from: from,
                    to: to,
                    date: dayLabel(dateKey(_date), DateTime.now()),
                    onFrom: () => _chooseWallet(wallets, target: false),
                    onTo: () => _chooseWallet(wallets, target: true),
                    onDate: _pickDate,
                  ),
                  if (needsReceived) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: ActionChip(
                        key: const Key('received-chip'),
                        shape: const StadiumBorder(),
                        avatar: const Icon(Icons.call_received, size: 18),
                        label: Text(_received.isEmpty
                            ? tr('Nhập số ${to.name} nhận được',
                                'Enter what ${to.name} receives')
                            : tr('${to.name} nhận $_received',
                                '${to.name} receives $_received')),
                        onPressed: () => _editReceived(to),
                      ),
                    ),
                  ],
                  if (!isTransfer) ...[
                    const SizedBox(height: 16),
                    _CategoryRail(
                      categories: categories,
                      selectedId: _categoryId,
                      onSelected: (id) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _categoryId = _categoryId == id ? null : id;
                          _error = null;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  InkWell(
                    key: const Key('note-row'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _editNote,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 10),
                      child: Row(children: [
                        Icon(Icons.notes_rounded,
                            size: 20, color: TichiColors.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _note.isEmpty
                                ? tr('Thêm ghi chú…', 'Add a note…')
                                : _note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _note.isEmpty
                                ? TichiText.caption
                                : TextStyle(
                                    fontSize: 14, color: TichiColors.ink),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (_error != null) FormError(_error!),
                ],
              ),
            ),
          ),
          CalculatorKeypad(
            calculator: _calc,
            suggestions: frequent,
            saving: _saving,
            onChanged: _changed,
            onSave: () => _save(wallets, categories),
          ),
        ]),
      ),
    );
  }
}

/// Số tiền lớn ở giữa; dòng biểu thức nhỏ phía trên khi đang tính.
class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.expression,
    required this.amount,
    required this.symbol,
  });

  final String expression;
  final String amount;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final tabular = const [FontFeature.tabularFigures()];
    return Column(children: [
      SizedBox(
        height: 22,
        child: Text(
          expression,
          key: const Key('amount-expression'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 15, color: TichiColors.muted, fontFeatures: tabular),
        ),
      ),
      SizedBox(
        height: 60,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                amount,
                key: const Key('amount-display'),
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: TichiColors.ink,
                    fontFeatures: tabular),
              ),
              const SizedBox(width: 6),
              Text(symbol,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: TichiColors.muted)),
            ],
          ),
        ),
      ),
    ]);
  }
}

/// Dòng "Ví · Ngày": các viên chạm để đổi.
class _ContextLine extends StatelessWidget {
  const _ContextLine({
    required this.isTransfer,
    required this.from,
    required this.to,
    required this.date,
    required this.onFrom,
    required this.onTo,
    required this.onDate,
  });

  final bool isTransfer;
  final WalletInfo? from;
  final WalletInfo? to;
  final String date;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onDate;

  Widget _pill(Key key, Widget? avatar, String label, VoidCallback onTap) =>
      ActionChip(
        key: key,
        shape: const StadiumBorder(),
        side: BorderSide(color: TichiColors.line),
        backgroundColor: TichiColors.surface,
        avatar: avatar,
        label: Text(label),
        onPressed: onTap,
      );

  Widget? _walletIcon(WalletInfo? wallet) => wallet == null
      ? null
      : IconAvatar(icon: wallet.icon, color: wallet.color, size: 22);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill(const Key('wallet-chip'), _walletIcon(from),
            from?.name ?? tr('Chọn ví', 'Choose wallet'), onFrom),
        if (isTransfer) ...[
          Icon(Icons.arrow_forward_rounded, size: 18, color: TichiColors.muted),
          _pill(const Key('to-wallet-chip'), _walletIcon(to),
              to?.name ?? tr('Chọn ví', 'Choose wallet'), onTo),
        ],
        _pill(
            const Key('date-chip'),
            Icon(Icons.calendar_today_rounded,
                size: 16, color: TichiColors.muted),
            date,
            onDate),
      ],
    );
  }
}

/// Hai hàng danh mục cuộn ngang, hay dùng nhất đứng đầu.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CategoryInfo> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  Widget _chip(CategoryInfo category) {
    final selected = category.id == selectedId;
    final tint = tintFor(category.color);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: Key('category-${category.id}'),
        avatar: Icon(iconFor(category.icon),
            size: 18, color: selected ? tint.foreground : TichiColors.muted),
        label: Text(category.name),
        selected: selected,
        selectedColor: tint.background,
        showCheckmark: false,
        shape: const StadiumBorder(),
        onSelected: (_) => onSelected(category.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = <CategoryInfo>[];
    final bottom = <CategoryInfo>[];
    for (var i = 0; i < categories.length; i++) {
      (i.isEven ? top : bottom).add(categories[i]);
    }
    return SingleChildScrollView(
      key: const Key('category-rail'),
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [for (final c in top) _chip(c)]),
          const SizedBox(height: 8),
          Row(children: [for (final c in bottom) _chip(c)]),
        ],
      ),
    );
  }
}

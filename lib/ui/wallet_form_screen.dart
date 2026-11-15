/// Danh sách ví và màn hình tạo hoặc sửa một ví.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import '../core/finance/schema.dart';
import 'icons.dart';
import 'widgets.dart';
import '../core/l10n.dart';

/// Tên các loại ví, đổi theo ngôn ngữ đang dùng.
Map<String, String> get walletTypeLabels => {
  'CASH': tr('Tiền mặt', 'Cash'),
  'BANK': tr('Ngân hàng', 'Bank'),
  'EWALLET': tr('Ví điện tử', 'E-wallet'),
  'SAVINGS': tr('Tiết kiệm', 'Savings'),
};

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.allWallets(includeArchived: true);
    final spending = all.where((w) => !w.isArchived && !w.isSavings).toList();
    final savings = all.where((w) => !w.isArchived && w.isSavings).toList();
    final archived = all.where((w) => w.isArchived).toList();

    void open(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    Widget section(String title, List<WalletInfo> wallets) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            FieldLabel(title),
            GroupCard(children: [
              for (final wallet in wallets)
                InkWell(
                  onTap: () => open(WalletFormScreen(walletId: wallet.id)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        IconAvatar(icon: wallet.icon, color: wallet.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(wallet.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  '${walletTypeLabels[wallet.type]} · '
                                  '${wallet.currencyCode}',
                                  style: TichiText.label),
                            ],
                          ),
                        ),
                        Text(
                          formatMinor(wallet.balanceMinor, wallet.currencyCode),
                          style: TichiText.amount.copyWith(
                              fontSize: 14,
                              color: wallet.balanceMinor < 0
                                  ? TichiColors.danger
                                  : TichiColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
          ],
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Ví', 'Wallet'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: tr('Thêm ví', 'Add wallet'),
            icon: const Icon(Icons.add),
            onPressed: () => open(const WalletFormScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            if (spending.isNotEmpty) section(tr('Ví chi tiêu', 'Spending wallets'), spending),
            if (savings.isNotEmpty) section(tr('Ví tiết kiệm', 'Savings wallet'), savings),
            if (archived.isNotEmpty) section(tr('Đã lưu trữ', 'Archived'), archived),
          ],
        ),
      ),
    );
  }
}

class WalletFormScreen extends StatefulWidget {
  /// [walletId] null là tạo ví mới.
  const WalletFormScreen({super.key, this.walletId, this.initialType = 'BANK'});

  final String? walletId;
  final String initialType;

  @override
  State<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends State<WalletFormScreen> {
  final _name = TextEditingController();
  final _opening = TextEditingController();
  late String _type;
  String _currency = 'VND';
  late String _icon;
  late String _color;
  bool _archived = false;
  String? _error;

  /// Ví đang sửa đã có giao dịch chưa. Chưa có thì vẫn đổi được loại tiền.
  bool _inUse = false;

  bool get _isEdit => widget.walletId != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _icon = defaultWalletIcon[_type] ?? 'wallet';
    _color = defaultWalletColor[_type] ?? 'emerald';
    final walletId = widget.walletId;
    if (walletId != null) {
      final wallet = StoreScope.read(context).wallet(walletId);
      _name.text = wallet.name;
      _type = wallet.type;
      _currency = wallet.currencyCode;
      _icon = wallet.icon;
      _color = wallet.color;
      _archived = wallet.isArchived;
      _inUse = StoreScope.read(context).walletInUse(walletId);
      final opening = StoreScope.read(context).openingBalance(walletId);
      _opening.text = opening == 0 ? '' : _plain(opening, _currency);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  String _plain(int minor, String currency) => amountText(minor, currency);

  void _selectType(String type) => setState(() {
        // Đổi loại thì đổi luôn biểu tượng mặc định, nếu chưa tự chọn khác.
        if (_icon == defaultWalletIcon[_type]) {
          _icon = defaultWalletIcon[type] ?? _icon;
        }
        if (_color == defaultWalletColor[_type]) {
          _color = defaultWalletColor[type] ?? _color;
        }
        _type = type;
      });

  void _save() {
    final store = StoreScope.read(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = tr('Đặt tên cho ví.', 'Give the wallet a name.'));
      return;
    }
    final opening = _opening.text.trim().isEmpty
        ? 0
        : parseMinor(_opening.text, _currency);
    if (opening == null) {
      setState(() => _error = tr('Số dư ban đầu không hợp lệ.', 'The opening balance is not valid.'));
      return;
    }
    try {
      final walletId = widget.walletId;
      if (walletId == null) {
        store.createWallet(
          name: _name.text,
          type: _type,
          currencyCode: _currency,
          openingBalanceMinor: opening,
          icon: _icon,
          color: _color,
        );
      } else {
        store.updateWallet(walletId,
            name: _name.text, icon: _icon, color: _color);
        if (_currency != store.wallet(walletId).currencyCode) {
          store.setWalletCurrency(walletId, _currency,
              openingBalanceMinor: opening);
        } else if (opening != store.openingBalance(walletId)) {
          store.setOpeningBalance(walletId, opening);
        }
      }
    } on FinanceException catch (error) {
      setState(() => _error = friendlyError(error));
      return;
    }
    Navigator.of(context).pop();
  }

  void _toggleArchive() {
    final store = StoreScope.read(context);
    try {
      store.setWalletArchived(widget.walletId!, !_archived);
    } on FinanceException catch (error) {
      setState(() => _error = friendlyError(error));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: tr('Đóng', 'Close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEdit ? tr('Sửa ví', 'Edit wallet') : tr('Ví mới', 'New wallet'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Center(child: IconAvatar(icon: _icon, color: _color, size: 64)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('wallet-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: tr('Tên ví', 'Wallet name'), hintText: tr('Ví dụ: Vietcombank, MoMo', 'e.g. Chase, PayPal')),
            ),
            const SizedBox(height: 16),
            FieldLabel(tr('Loại ví', 'Wallet type')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in walletTypeLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    showCheckmark: false,
                    // Loại ví không đổi được sau khi tạo.
                    onSelected: _isEdit ? null : (_) => _selectType(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FieldLabel(tr('Loại tiền', 'Currency')),
            Wrap(
              spacing: 8,
              children: [
                for (final currency in const ['VND', 'USD'])
                  ChoiceChip(
                    label: Text(currency),
                    selected: _currency == currency,
                    showCheckmark: false,
                    onSelected: _isEdit && _inUse
                        ? null
                        : (_) => setState(() {
                              if (_currency != currency) _opening.clear();
                              _currency = currency;
                            }),
                  ),
              ],
            ),
            if (_isEdit && _inUse)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    tr('Ví đã có giao dịch nên không đổi được loại tiền.',
                        'This wallet has transactions, so its currency is locked.'),
                    style: TichiText.label),
              ),
            ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('wallet-opening'),
                controller: _opening,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: _currency == 'USD'),
                inputFormatters: moneyFormatters(_currency),
                decoration: InputDecoration(
                  labelText: _isEdit ? tr('Số dư ban đầu', 'Opening balance') : tr('Số dư hiện có', 'Current balance'),
                  helperText: _isEdit
                      ? tr('Số tiền ví có trước khi bắt đầu ghi trên Tichi. Sửa số '
                          'này thì số dư hiện tại đổi theo.', 'Money the wallet had before you started using Tichi. Changing ' 'it changes the current balance too.')
                      : (_type == 'SAVINGS'
                          ? tr('Tiền có sẵn sẽ là "Chưa gắn mục tiêu"; bạn chia '
                              'cho mục tiêu sau.', 'Existing money becomes "Unassigned"; you can assign it ' 'to goals later.')
                          : tr('Để trống nếu ví chưa có tiền.', 'Leave empty if the wallet is empty.')),
                  helperMaxLines: 2,
                  suffixText: _currency == 'USD' ? 'USD' : '₫',
                ),
              ),
            ],
            const SizedBox(height: 16),
            FieldLabel(tr('Biểu tượng và màu', 'Icon & color')),
            IconColorPicker(
              icons: walletIconChoices,
              iconKey: _icon,
              onIcon: (key) => setState(() => _icon = key),
              colorKey: _color,
              onColor: (key) => setState(() => _color = key),
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('wallet-save'),
              onPressed: _save,
              child: Text(_isEdit ? tr('Lưu', 'Save') : tr('Tạo ví', 'Create wallet')),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _toggleArchive,
                style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: Text(_archived ? tr('Mở lại ví', 'Unarchive wallet') : tr('Lưu trữ ví này', 'Archive this wallet')),
              ),
              Text(
                _archived
                    ? tr('Ví đang lưu trữ: không dùng cho giao dịch mới nhưng vẫn '
                        'tính vào tổng tài sản.', 'Archived wallet: not used for new transactions but still ' 'counted in your total balance.')
                    : tr('Lưu trữ để ẩn ví khỏi danh sách chọn. Lịch sử và số dư '
                        'vẫn được giữ.', 'Archive to hide the wallet from pickers. History and balance ' 'are kept.'),
                textAlign: TextAlign.center,
                style: TichiText.label,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

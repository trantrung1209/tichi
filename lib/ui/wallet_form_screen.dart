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

const Map<String, String> walletTypeLabels = {
  'CASH': 'Tiền mặt',
  'BANK': 'Ngân hàng',
  'EWALLET': 'Ví điện tử',
  'SAVINGS': 'Tiết kiệm',
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
        title: const Text('Ví',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Thêm ví',
            icon: const Icon(Icons.add),
            onPressed: () => open(const WalletFormScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            if (spending.isNotEmpty) section('Ví chi tiêu', spending),
            if (savings.isNotEmpty) section('Ví tiết kiệm', savings),
            if (archived.isNotEmpty) section('Đã lưu trữ', archived),
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
      setState(() => _error = 'Đặt tên cho ví.');
      return;
    }
    final opening = _opening.text.trim().isEmpty
        ? 0
        : parseMinor(_opening.text, _currency);
    if (opening == null) {
      setState(() => _error = 'Số dư ban đầu không hợp lệ.');
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
        if (opening != store.openingBalance(walletId)) {
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
          tooltip: 'Đóng',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEdit ? 'Sửa ví' : 'Ví mới',
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
              decoration: const InputDecoration(
                  labelText: 'Tên ví', hintText: 'Ví dụ: Vietcombank, MoMo'),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Loại ví'),
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
            const FieldLabel('Loại tiền'),
            Wrap(
              spacing: 8,
              children: [
                for (final currency in const ['VND', 'USD'])
                  ChoiceChip(
                    label: Text(currency),
                    selected: _currency == currency,
                    showCheckmark: false,
                    onSelected: _isEdit
                        ? null
                        : (_) => setState(() => _currency = currency),
                  ),
              ],
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
                  labelText: _isEdit ? 'Số dư ban đầu' : 'Số dư hiện có',
                  helperText: _isEdit
                      ? 'Số tiền ví có trước khi bắt đầu ghi trên Tichi. Sửa số '
                          'này thì số dư hiện tại đổi theo.'
                      : (_type == 'SAVINGS'
                          ? 'Tiền có sẵn sẽ là "Chưa gắn mục tiêu"; bạn chia '
                              'cho mục tiêu sau.'
                          : 'Để trống nếu ví chưa có tiền.'),
                  helperMaxLines: 2,
                  suffixText: _currency == 'USD' ? 'USD' : '₫',
                ),
              ),
            ],
            const SizedBox(height: 16),
            const FieldLabel('Biểu tượng và màu'),
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
              child: Text(_isEdit ? 'Lưu' : 'Tạo ví'),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _toggleArchive,
                style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: Text(_archived ? 'Mở lại ví' : 'Lưu trữ ví này'),
              ),
              Text(
                _archived
                    ? 'Ví đang lưu trữ: không dùng cho giao dịch mới nhưng vẫn '
                        'tính vào tổng tài sản.'
                    : 'Lưu trữ để ẩn ví khỏi danh sách chọn. Lịch sử và số dư '
                        'vẫn được giữ.',
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

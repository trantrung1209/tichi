/// Thành phần giao diện dùng chung.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import 'icons.dart';
import '../core/l10n.dart';

/// Một dòng giao dịch: biểu tượng, tên, danh mục và ví, số tiền.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx});

  final TransactionView tx;

  @override
  Widget build(BuildContext context) {
    final isSaving = tx.type == 'TRANSFER' && tx.destinationIsSavings;
    final isWithdraw = tx.type == 'TRANSFER' && tx.sourceIsSavings;
    final String fallbackTitle;
    final String subtitle;
    final String amountText;
    final Color amountColor;
    final String icon;
    final String color;
    switch (tx.type) {
      case 'INCOME':
        fallbackTitle = tx.categoryName ?? tr('Khoản thu', 'Income');
        subtitle = '${tx.categoryName ?? 'Thu'} · ${tx.destinationWalletName}';
        amountText = formatMinor(tx.amountMinor, tx.currency, showPlus: true);
        amountColor = TichiColors.primary;
        icon = tx.categoryIcon ?? 'salary';
        color = tx.categoryColor ?? 'green';
      case 'EXPENSE':
        fallbackTitle = tx.categoryName ?? tr('Khoản chi', 'Expense');
        subtitle = '${tx.categoryName ?? 'Chi'} · ${tx.sourceWalletName}';
        amountText = formatMinor(-tx.amountMinor, tx.currency);
        amountColor = TichiColors.ink;
        icon = tx.categoryIcon ?? 'more';
        color = tx.categoryColor ?? 'stone';
      default:
        fallbackTitle = isSaving
            ? tr('Tiết kiệm', 'Savings')
            : (isWithdraw ? tr('Rút tiết kiệm', 'Savings withdrawal') : tr('Chuyển ví', 'Transfer'));
        subtitle = '${tx.sourceWalletName} → ${tx.destinationWalletName}';
        amountText = formatMinor(tx.amountMinor, tx.currency);
        amountColor = TichiColors.muted;
        icon = (isSaving || isWithdraw) ? 'coins' : 'transfer';
        color = (isSaving || isWithdraw) ? 'gold' : 'stone';
    }
    final note = tx.note?.trim();
    final title = (note == null || note.isEmpty) ? fallbackTitle : note;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconAvatar(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TichiText.label),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(amountText,
                style: TichiText.amount
                    .copyWith(fontSize: 14, color: amountColor)),
          ],
        ),
      ),
    );
  }
}

/// Thẻ trắng bo góc chứa một nhóm dòng, có đường kẻ giữa các dòng.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1));
      rows.add(children[i]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: rows),
      ),
    );
  }
}

/// Thanh tiến độ mảnh.
class ProgressBar extends StatelessWidget {
  const ProgressBar(
      {super.key, required this.percent, this.color, this.height = 8});

  final int percent;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Thanh chạy dần tới mức mới thay vì nhảy ngay.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent.clamp(0, 100) / 100),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value,
          minHeight: height,
          backgroundColor: TichiColors.track,
          color: color ?? TichiColors.primary,
        ),
      ),
    );
  }
}

/// Số tiền lớn có hiệu ứng đếm tới số mới. Số quá dài thì tự thu nhỏ.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount({
    super.key,
    required this.minor,
    required this.currency,
    this.style,
    this.textKey,
  });

  final int minor;
  final String currency;
  final TextStyle? style;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: minor.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(formatMinor(value.round(), currency),
            key: textKey, maxLines: 1, style: style),
      ),
    );
  }
}

/// Màu thanh tiến độ ngân sách theo mức: ok, warning, over.
Color budgetColor(String level) => switch (level) {
      'over' => TichiColors.danger,
      'warning' => TichiColors.warning,
      _ => TichiColors.primary,
    };

/// Tiêu đề nhỏ phía trên một nhóm trường nhập.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: TichiColors.muted)),
    );
  }
}

/// Một dòng chọn: nhãn bên trái, giá trị và mũi tên bên phải.
class PickerRow extends StatelessWidget {
  const PickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: TichiColors.muted)),
            const SizedBox(width: 12),
            const Spacer(),
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 20, color: TichiColors.muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tự thêm dấu ngăn cách hàng nghìn khi gõ số tiền (VND: "1.000.000",
/// USD: "1,234.56") và giữ con trỏ đúng chỗ.
class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter(this.currency);

  final String currency;

  bool _isSignificant(String char) =>
      RegExp(r'\d').hasMatch(char) || (currency == 'USD' && char == '.');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    var cursor = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, text.length)
        : text.length;

    // Nhiều bàn phím chỉ có dấu phẩy cho phần lẻ. Với USD, dấu phẩy vừa gõ
    // được hiểu là dấu thập phân (12,5 → 12.5), không phải dấu hàng nghìn.
    if (currency == 'USD' &&
        text.length == oldValue.text.length + 1 &&
        cursor > 0 &&
        text[cursor - 1] == ',') {
      final hasDot = text.contains('.');
      text = text.replaceRange(cursor - 1, cursor, hasDot ? '' : '.');
      if (hasDot) cursor -= 1;
    }

    // Xóa lùi đúng vào dấu ngăn cách: xóa luôn chữ số đứng trước nó, nếu không
    // dấu sẽ hiện lại ngay và trông như phím xóa không chạy.
    final separator = currency == 'USD' ? ',' : '.';
    if (oldValue.text.length - text.length == 1 &&
        newValue.selection.isCollapsed &&
        cursor < oldValue.text.length &&
        oldValue.text[cursor] == separator &&
        text == oldValue.text.replaceRange(cursor, cursor + 1, '') &&
        cursor > 0) {
      text = text.replaceRange(cursor - 1, cursor, '');
      cursor -= 1;
    }

    var significantBefore = 0;
    for (var i = 0; i < cursor; i++) {
      if (_isSignificant(text[i])) significantBefore++;
    }
    final formatted = groupAmountInput(text, currency);
    // Rung nhẹ mỗi lần số tiền thay đổi khi gõ, như bấm phím máy tính.
    if (formatted != oldValue.text) HapticFeedback.selectionClick();
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < significantBefore) {
      if (_isSignificant(formatted[offset])) seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Bộ định dạng cho mọi ô nhập số tiền.
List<TextInputFormatter> moneyFormatters(String currency) =>
    [MoneyInputFormatter(currency)];

/// Ô nhập số tiền cỡ lớn, canh giữa. Chữ "0" mờ chỉ hiện khi chưa chạm vào
/// ô, để con trỏ không nằm đè lên số 0.
class AmountInput extends StatefulWidget {
  const AmountInput({
    super.key,
    required this.controller,
    required this.currency,
    this.autofocus = false,
    this.onChanged,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String currency;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usd = widget.currency == 'USD';
    return TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: usd),
      inputFormatters: moneyFormatters(widget.currency),
      style: const TextStyle(
          fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1),
      decoration: InputDecoration(
        hintText: _focus.hasFocus ? null : '0',
        suffixText: usd ? 'USD' : '₫',
        border: InputBorder.none,
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// Dòng báo lỗi màu đỏ dưới biểu mẫu.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(message,
          key: const Key('form-error'),
          style: TextStyle(color: TichiColors.danger, fontSize: 13)),
    );
  }
}

/// Bảng chọn ví từ dưới lên. Trả về mã ví đã chọn hoặc null.
Future<String?> pickWallet(BuildContext context, List<WalletInfo> wallets,
    {String? selectedId, String? title}) {
  final heading = title ?? tr('Chọn ví', 'Choose wallet');
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(heading, style: TichiText.section),
            ),
            if (wallets.isEmpty)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(tr('Chưa có ví phù hợp.', 'No matching wallets.'), style: TichiText.caption),
              ),
            for (final wallet in wallets)
              ListTile(
                leading: IconAvatar(icon: wallet.icon, color: wallet.color),
                title: Text(wallet.name),
                subtitle: Text(
                    tr('Số dư ${formatMinor(wallet.balanceMinor, wallet.currencyCode)}', 'Balance ${formatMinor(wallet.balanceMinor, wallet.currencyCode)}')),
                trailing: wallet.id == selectedId
                    ? Icon(Icons.check, color: TichiColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, wallet.id),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Hộp thoại xác nhận. Trả về true nếu người dùng đồng ý.
Future<bool> confirmAction(BuildContext context,
    {required String title,
    required String message,
    required String confirmLabel}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(tr('Hủy', 'Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: TichiColors.danger),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Hộp thoại nhập tỷ giá USD. Trả về true nếu đã lưu.
Future<bool> showRateDialog(BuildContext context) async {
  final store = StoreScope.read(context);
  final controller =
      TextEditingController(
          text: store.usdVndRate == null
              ? ''
              : amountText(store.usdVndRate!, 'VND'));
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(tr('Tỷ giá USD', 'USD exchange rate')),
        content: TextField(
          key: const Key('rate-field'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: moneyFormatters('VND'),
          decoration: InputDecoration(
            labelText: tr('Số đồng cho 1 USD', 'Dong per 1 USD'),
            hintText: tr('Ví dụ 26.300', 'e.g. 26,300'),
            errorText: error,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Hủy', 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              final rate = parseMinor(controller.text, 'VND');
              if (rate == null || rate == 0) {
                setState(() => error = tr('Nhập một số lớn hơn 0', 'Enter a number greater than 0'));
                return;
              }
              store.setUsdVndRate(rate);
              Navigator.pop(dialogContext, true);
            },
            child: Text(tr('Lưu', 'Save')),
          ),
        ],
      ),
    ),
  );
  // Không dispose controller ngay: hộp thoại còn dùng nó trong lúc đóng.
  return saved ?? false;
}

/// Thẻ trống với lời nhắn và một nút hành động.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            IconAvatar(icon: icon, color: 'emerald', size: 56),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center, style: TichiText.caption),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bàn phím máy tính của màn Thêm giao dịch: chip gợi ý số tiền, phím số,
/// phép tính và phím Lưu cao hai hàng.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../core/finance/calculator.dart';
import '../core/finance/money.dart';
import '../core/l10n.dart';

class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.calculator,
    required this.onChanged,
    required this.onSave,
    required this.suggestions,
    this.saving = false,
  });

  final AmountCalculator calculator;

  /// Gọi sau mỗi lần bấm phím để màn hình vẽ lại số.
  final VoidCallback onChanged;

  /// Bấm phím Lưu khi không còn phép tính dở.
  final VoidCallback onSave;

  /// Số tiền gợi ý (đơn vị nhỏ nhất) khi chưa gõ hoặc gõ số nhỏ.
  final List<int> suggestions;
  final bool saving;

  static const double _keyHeight = 52;
  static const double _gap = 8;

  void _press(VoidCallback action) {
    HapticFeedback.selectionClick();
    action();
    onChanged();
  }

  void _equalsOrSave() {
    if (calculator.hasPendingOperation) {
      HapticFeedback.lightImpact();
      calculator.collapse();
      onChanged();
      return;
    }
    onSave();
  }

  @override
  Widget build(BuildContext context) {
    final usd = calculator.currency == 'USD';
    final pending = calculator.hasPendingOperation;
    final value = calculator.evaluate().value ?? 0;
    final canSave = !saving && (pending || value > 0);
    final typed = amountSuggestions(calculator.currentText, calculator.currency);
    final chips = typed.isNotEmpty ? typed : suggestions;

    Widget digit(String d) => _Key(
          key: Key('key-$d'),
          label: d,
          onTap: () => _press(() => calculator.digit(d)),
        );
    Widget op(CalcOp o, String name) => _Key(
          key: Key('key-$name'),
          label: o.symbol,
          style: _KeyStyle.operator,
          onTap: () => _press(() => calculator.operator(o)),
        );
    Widget row(List<Widget> keys) => SizedBox(
          height: _keyHeight,
          child: Row(children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(child: keys[i]),
            ],
          ]),
        );
    const vGap = SizedBox(height: _gap);

    return Container(
      color: TichiColors.background,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final amount in chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    key: Key('suggest-$amount'),
                    label: Text(formatMinor(amount, calculator.currency)),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: TichiColors.line),
                    backgroundColor: TichiColors.surface,
                    onPressed: () => _press(() =>
                        calculator.replaceCurrent(amount)),
                  ),
                ),
            ],
          ),
        ),
        vGap,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: Column(children: [
              row([
                _Key(
                  key: const Key('key-clear'),
                  label: 'C',
                  style: _KeyStyle.operator,
                  onTap: () => _press(calculator.clear),
                ),
                op(CalcOp.divide, 'divide'),
                op(CalcOp.multiply, 'times'),
              ]),
              vGap,
              row([digit('7'), digit('8'), digit('9')]),
              vGap,
              row([digit('4'), digit('5'), digit('6')]),
              vGap,
              row([digit('1'), digit('2'), digit('3')]),
              vGap,
              row([
                digit('000'),
                digit('0'),
                _Key(
                  key: const Key('key-decimal'),
                  label: ',',
                  enabled: usd,
                  onTap: () => _press(calculator.decimal),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: Column(children: [
              SizedBox(
                height: _keyHeight,
                child: _Key(
                  key: const Key('key-back'),
                  icon: Icons.backspace_outlined,
                  semantic: tr('Xóa', 'Delete'),
                  style: _KeyStyle.operator,
                  onTap: () => _press(calculator.backspace),
                  onLongPress: () => _press(calculator.clear),
                ),
              ),
              vGap,
              SizedBox(height: _keyHeight, child: op(CalcOp.subtract, 'minus')),
              vGap,
              SizedBox(height: _keyHeight, child: op(CalcOp.add, 'plus')),
              vGap,
              SizedBox(
                height: _keyHeight * 2 + _gap,
                child: _Key(
                  key: const Key('save-button'),
                  label: pending ? '=' : tr('Lưu', 'Save'),
                  icon: pending ? null : Icons.check_rounded,
                  style: _KeyStyle.save,
                  enabled: canSave,
                  onTap: _equalsOrSave,
                ),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }
}

enum _KeyStyle { number, operator, save }

/// Một phím: lún nhẹ khi chạm.
class _Key extends StatefulWidget {
  const _Key({
    super.key,
    this.label,
    this.icon,
    this.semantic,
    required this.onTap,
    this.onLongPress,
    this.style = _KeyStyle.number,
    this.enabled = true,
  });

  final String? label;
  final IconData? icon;
  final String? semantic;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final _KeyStyle style;
  final bool enabled;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final save = widget.style == _KeyStyle.save;
    final operator = widget.style == _KeyStyle.operator;
    final Color background;
    final Color foreground;
    if (save) {
      background = widget.enabled ? TichiColors.brand : TichiColors.track;
      foreground = widget.enabled ? Colors.white : TichiColors.muted;
    } else if (operator) {
      background = TichiColors.primarySoft;
      foreground = TichiColors.primary;
    } else {
      background = TichiColors.surface;
      foreground = widget.enabled ? TichiColors.ink : TichiColors.line;
    }
    final label = widget.label;
    final icon = widget.icon;
    final content = <Widget>[
      if (icon != null) Icon(icon, color: foreground, size: save ? 22 : 24),
      if (icon != null && label != null) const SizedBox(height: 4),
      if (label != null)
        Text(label,
            style: TextStyle(
                fontSize: save ? 17 : (operator ? 24 : 24),
                fontWeight: save ? FontWeight.w700 : FontWeight.w500,
                color: foreground,
                fontFeatures: const [FontFeature.tabularFigures()])),
    ];
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semantic ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _set(true) : null,
        onTapUp: widget.enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 80),
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
              border: save || operator
                  ? null
                  : Border.all(color: TichiColors.line.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: content),
          ),
        ),
      ),
    );
  }
}

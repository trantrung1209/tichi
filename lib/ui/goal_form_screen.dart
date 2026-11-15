/// Tạo mới hoặc sửa một mục tiêu tiết kiệm.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import 'icons.dart';
import 'widgets.dart';
import '../core/l10n.dart';

class GoalFormScreen extends StatefulWidget {
  /// [goalId] null là tạo mục tiêu mới.
  const GoalFormScreen({super.key, this.goalId});

  final String? goalId;

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String _icon = 'savings';
  int _priority = 1;
  late DateTime _targetDate;
  String? _walletId;
  String? _error;

  bool get _isEdit => widget.goalId != null;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final now = DateTime.now();
    _targetDate = DateTime(now.year + 1, now.month, now.day);
    final vaults = store.savingsWallets();
    if (vaults.isNotEmpty) _walletId = vaults.first.id;
    final goalId = widget.goalId;
    if (goalId != null) {
      final goal = store.goal(goalId);
      _name.text = goal.name;
      _target.text = amountText(goal.targetMinor, goal.currencyCode);
      _icon = goal.icon;
      _priority = goal.priority;
      final parts = goal.targetDate.split('-').map(int.parse).toList();
      _targetDate = DateTime(parts[0], parts[1], parts[2]);
      _walletId = goal.savingsWalletId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate.isBefore(now) ? now : _targetDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 50),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _save() {
    final store = StoreScope.read(context);
    final walletId = _walletId;
    if (walletId == null) {
      setState(() => _error = tr('Chọn một ví tiết kiệm.', 'Choose a savings wallet.'));
      return;
    }
    final currency = store.wallet(walletId).currencyCode;
    final target = parseMinor(_target.text, currency);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = tr('Đặt tên cho mục tiêu.', 'Give your goal a name.'));
      return;
    }
    if (target == null || target <= 0) {
      setState(() => _error = tr('Nhập số tiền mục tiêu lớn hơn 0.', 'Enter a target amount greater than 0.'));
      return;
    }
    try {
      final goalId = widget.goalId;
      if (goalId == null) {
        store.createGoal(
          name: _name.text,
          targetMinor: target,
          savingsWalletId: walletId,
          startDate: dateKey(DateTime.now()),
          targetDate: dateKey(_targetDate),
          priority: _priority,
          icon: _icon,
        );
      } else {
        store.updateGoal(
          goalId,
          name: _name.text,
          targetMinor: target,
          targetDate: dateKey(_targetDate),
          priority: _priority,
          icon: _icon,
        );
      }
    } on FinanceException catch (error) {
      setState(() => _error = friendlyError(error));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final vaults = store.savingsWallets();
    WalletInfo? vault;
    for (final wallet in vaults) {
      if (wallet.id == _walletId) vault = wallet;
    }
    final currency = vault?.currencyCode ?? store.baseCurrency;

    // Số gợi ý mỗi ngày, tính ngay khi nhập.
    final target = parseMinor(_target.text, currency);
    final today = DateTime.now();
    final days = DateTime(_targetDate.year, _targetDate.month, _targetDate.day)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays +
        1;
    final saved = _isEdit ? store.goal(widget.goalId!).savedMinor : 0;
    final remaining = (target ?? 0) - saved;
    final daily = (remaining > 0 && days > 0)
        ? (remaining + days - 1) ~/ days
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: tr('Đóng', 'Close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEdit ? tr('Sửa mục tiêu', 'Edit goal') : tr('Mục tiêu mới', 'New goal'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            TextField(
              key: const Key('goal-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  labelText: tr('Tên mục tiêu', 'Goal name'), hintText: tr('Ví dụ: Du lịch Nhật Bản', 'e.g. Trip to Japan')),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('goal-target'),
              controller: _target,
              keyboardType:
                  TextInputType.numberWithOptions(decimal: currency == 'USD'),
              inputFormatters: moneyFormatters(currency),
              decoration: InputDecoration(
                labelText: tr('Số tiền mục tiêu', 'Target amount'),
                suffixText: currency == 'USD' ? 'USD' : '₫',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            GroupCard(children: [
              PickerRow(
                label: tr('Ngày hoàn thành', 'Target date'),
                value: shortDate(dateKey(_targetDate)),
                onTap: _pickDate,
              ),
              PickerRow(
                label: tr('Ví tiết kiệm', 'Savings wallet'),
                value: vault?.name ?? tr('Chọn ví', 'Choose wallet'),
                leading: vault == null
                    ? null
                    : IconAvatar(icon: vault.icon, color: vault.color, size: 28),
                // Ví của mục tiêu không đổi được sau khi tạo.
                onTap: _isEdit
                    ? null
                    : () async {
                        final picked = await pickWallet(context, vaults,
                            selectedId: _walletId, title: tr('Ví tiết kiệm', 'Savings wallet'));
                        if (picked != null) setState(() => _walletId = picked);
                      },
              ),
            ]),
            const SizedBox(height: 16),
            FieldLabel(tr('Mức ưu tiên', 'Priority')),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(tr('Thấp', 'Low'))),
                ButtonSegment(value: 1, label: Text(tr('Vừa', 'Medium'))),
                ButtonSegment(value: 2, label: Text(tr('Cao', 'High'))),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 16),
            FieldLabel(tr('Biểu tượng', 'Icon')),
            IconColorPicker(
              icons: goalIconChoices,
              iconKey: _icon,
              onIcon: (key) => setState(() => _icon = key),
            ),
            if (daily != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TichiColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Để kịp hạn trong $days ngày, nên tiết kiệm khoảng', 'To make it in $days days, save about'),
                        style: TextStyle(
                            fontSize: 12, color: TichiColors.softText)),
                    const SizedBox(height: 4),
                    Text(tr('${formatMinor(daily, currency)} mỗi ngày', '${formatMinor(daily, currency)} a day'),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: TichiColors.primary)),
                  ],
                ),
              ),
            ],
            if (_error != null) FormError(_error!),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('goal-save'),
              onPressed: _save,
              child: Text(_isEdit ? tr('Lưu', 'Save') : tr('Tạo mục tiêu', 'Create goal')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một màn hình cho ba thao tác tiết kiệm:
/// - Tiết kiệm ngay: chuyển tiền thật từ ví thường vào ví tiết kiệm.
/// - Rút tiền: chuyển tiền của một mục tiêu về ví thường.
/// - Chia tiền có sẵn: gắn phần "Chưa gắn mục tiêu" cho một mục tiêu.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import '../core/savings/savings_center.dart';
import 'icons.dart';
import 'widgets.dart';
import '../core/l10n.dart';

enum SavingsMode { contribute, withdraw, allocate }

class SavingsMoveScreen extends StatefulWidget {
  const SavingsMoveScreen({
    super.key,
    required this.mode,
    this.goalId,
    this.savingsWalletId,
  });

  final SavingsMode mode;
  final String? goalId;

  /// Dùng cho chế độ chia tiền có sẵn: ví tiết kiệm có tiền chưa gắn.
  final String? savingsWalletId;

  @override
  State<SavingsMoveScreen> createState() => _SavingsMoveScreenState();
}

class _SavingsMoveScreenState extends State<SavingsMoveScreen> {
  final _amount = TextEditingController();
  String? _goalId;
  String? _walletId;
  String? _error;
  bool _saving = false;
  late final String _requestId;

  SavingsMode get _mode => widget.mode;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    _requestId = store.newRequestId();
    _goalId = widget.goalId ?? _defaultGoal(store);
    _prefill(store);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Các mục tiêu chọn được trong chế độ hiện tại.
  List<GoalProgress> _goals(AppStore store) {
    final all = store.goals().where((g) => g.status != 'ARCHIVED');
    return switch (_mode) {
      SavingsMode.withdraw => all.where((g) => g.savedMinor > 0).toList(),
      SavingsMode.allocate => all
          .where((g) =>
              widget.savingsWalletId == null ||
              g.savingsWalletId == widget.savingsWalletId)
          .toList(),
      SavingsMode.contribute => all.toList(),
    };
  }

  String? _defaultGoal(AppStore store) {
    final goals = _goals(store);
    for (final goal in goals) {
      if (goal.status == 'ACTIVE') return goal.goalId;
    }
    return goals.isEmpty ? null : goals.first.goalId;
  }

  /// Điền sẵn số gợi ý và ví phù hợp khi đổi mục tiêu.
  void _prefill(AppStore store) {
    final goalId = _goalId;
    if (goalId == null) return;
    final goal = store.goal(goalId);
    final wallets = _wallets(store, goal);
    if (!wallets.any((w) => w.id == _walletId)) {
      // Góp tiền: chọn sẵn ví đang có nhiều tiền nhất để ít bị báo thiếu tiền.
      final sorted = [...wallets];
      if (_mode == SavingsMode.contribute) {
        sorted.sort((a, b) => b.balanceMinor.compareTo(a.balanceMinor));
      }
      _walletId = sorted.isEmpty ? null : sorted.first.id;
    }
    if (_mode == SavingsMode.contribute) {
      final suggestion = store.suggestion(goalId, DateTime.now());
      if (suggestion != null) {
        _amount.text = _plain(suggestion.dailyMinor, goal.currencyCode);
      }
    }
  }

  /// Ví thường cùng loại tiền với mục tiêu: nguồn khi tiết kiệm, đích khi rút.
  List<WalletInfo> _wallets(AppStore store, GoalProgress goal) => store
      .spendingWallets()
      .where((w) => w.currencyCode == goal.currencyCode)
      .toList();

  String _plain(int minor, String currency) => amountText(minor, currency);

  Future<void> _chooseGoal(AppStore store) async {
    final goals = _goals(store);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final goal in goals)
              ListTile(
                leading: IconAvatar(icon: goal.icon, color: 'emerald'),
                title: Text(goal.name),
                subtitle: Text(
                    '${formatMinor(goal.savedMinor, goal.currencyCode)} / '
                    '${formatMinor(goal.targetMinor, goal.currencyCode)}'),
                trailing: goal.goalId == _goalId
                    ? Icon(Icons.check, color: TichiColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, goal.goalId),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _goalId = picked;
      _error = null;
      _prefill(store);
    });
  }

  void _fail(String message) => setState(() {
        _saving = false;
        _error = message;
      });

  void _confirm(AppStore store, GoalProgress goal) {
    final amount = parseMinor(_amount.text, goal.currencyCode);
    if (amount == null || amount <= 0) return _fail(tr('Nhập số tiền lớn hơn 0.', 'Enter an amount greater than 0.'));
    final date = dateKey(DateTime.now());
    setState(() => _saving = true);
    try {
      switch (_mode) {
        case SavingsMode.contribute:
          final walletId = _walletId;
          if (walletId == null) return _fail(tr('Chọn ví lấy tiền.', 'Choose a wallet to take money from.'));
          store.contribute(
              requestId: _requestId,
              goalId: goal.goalId,
              fromWalletId: walletId,
              amountMinor: amount,
              date: date);
        case SavingsMode.withdraw:
          final walletId = _walletId;
          if (walletId == null) return _fail(tr('Chọn ví nhận tiền.', 'Choose a wallet to receive the money.'));
          store.withdraw(
              requestId: _requestId,
              goalId: goal.goalId,
              toWalletId: walletId,
              amountMinor: amount,
              date: date);
        case SavingsMode.allocate:
          store.allocate(
              requestId: _requestId,
              goalId: goal.goalId,
              amountMinor: amount,
              date: date);
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
    final title = switch (_mode) {
      SavingsMode.contribute => tr('Tiết kiệm ngay', 'Save now'),
      SavingsMode.withdraw => tr('Rút tiền tiết kiệm', 'Withdraw savings'),
      SavingsMode.allocate => tr('Chia tiền có sẵn', 'Assign existing money'),
    };
    final goalId = _goalId;
    if (goalId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: EdgeInsets.all(20),
          child: Text(tr('Chưa có mục tiêu phù hợp.', 'No matching goals yet.'), style: TichiText.caption),
        ),
      );
    }
    final goal = store.goal(goalId);
    final c = goal.currencyCode;
    final wallets = _wallets(store, goal);
    WalletInfo? wallet;
    for (final w in wallets) {
      if (w.id == _walletId) wallet = w;
    }
    final vault = store.wallet(goal.savingsWalletId);
    final amount = parseMinor(_amount.text, c) ?? 0;
    final free = store.unallocated(goal.savingsWalletId);

    final int after;
    final String explain;
    switch (_mode) {
      case SavingsMode.contribute:
        after = goal.savedMinor + amount;
        explain = tr('Đây là một lần chuyển ví: ${wallet?.name ?? 'ví nguồn'} '
            'giảm, ${vault.name} tăng. Tổng tài sản không đổi và khoản này '
            'không tính là chi tiêu.', 'This is a transfer: ${wallet?.name ?? 'the source wallet'} ' 'goes down, ${vault.name} goes up. Your total balance stays the same and this ' 'is not counted as spending.');
      case SavingsMode.withdraw:
        after = goal.savedMinor - amount;
        explain = tr('Đây là chuyển ví, không tính là thu nhập. Chỉ mục tiêu '
            '"${goal.name}" bị giảm; các mục tiêu khác giữ nguyên.', 'This is a transfer, not income. Only the goal ' '"${goal.name}" goes down; other goals stay the same.');
      case SavingsMode.allocate:
        after = goal.savedMinor + amount;
        explain = tr('Tiền đã nằm sẵn trong ${vault.name}, chỉ gắn cho mục tiêu. '
            'Không có chuyển ví. Còn ${formatMinor(free, c)} chưa gắn mục tiêu.', 'The money is already in ${vault.name}; it\'s just assigned to the goal. ' 'No transfer. ${formatMinor(free, c)} still unassigned.');
    }
    final beforePercent = goal.percent;
    final afterPercent = after <= 0 ? 0 : after * 100 ~/ goal.targetMinor;
    final confirmLabel = switch (_mode) {
      SavingsMode.contribute => tr('Xác nhận tiết kiệm', 'Confirm saving'),
      SavingsMode.withdraw => tr('Xác nhận rút', 'Confirm withdrawal'),
      SavingsMode.allocate => tr('Gắn cho mục tiêu', 'Assign to goal'),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: tr('Đóng', 'Close'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            GroupCard(children: [
              PickerRow(
                label: tr('Mục tiêu', 'Goal'),
                value: goal.name,
                leading: IconAvatar(icon: goal.icon, color: 'emerald', size: 28),
                onTap: widget.goalId == null ? () => _chooseGoal(store) : null,
              ),
            ]),
            const SizedBox(height: 12),
            AmountInput(
              fieldKey: const Key('move-amount'),
              controller: _amount,
              currency: c,
              autofocus: _amount.text.isEmpty,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            GroupCard(children: [
              if (_mode == SavingsMode.contribute)
                PickerRow(
                  label: tr('Lấy từ ví', 'Take from'),
                  value: wallet == null
                      ? tr('Chọn ví', 'Choose wallet')
                      : '${wallet.name} · ${formatMinor(wallet.balanceMinor, c)}',
                  onTap: () async {
                    final picked = await pickWallet(context, wallets,
                        selectedId: _walletId, title: tr('Lấy từ ví', 'Take from'));
                    if (picked != null) setState(() => _walletId = picked);
                  },
                ),
              PickerRow(
                label: _mode == SavingsMode.withdraw ? tr('Rút từ', 'Withdraw from') : tr('Chuyển vào', 'Move into'),
                value: vault.name,
                onTap: null,
              ),
              if (_mode == SavingsMode.withdraw)
                PickerRow(
                  label: tr('Chuyển về ví', 'Send to wallet'),
                  value: wallet?.name ?? tr('Chọn ví', 'Choose wallet'),
                  onTap: () async {
                    final picked = await pickWallet(context, wallets,
                        selectedId: _walletId, title: tr('Chuyển về ví', 'Send to wallet'));
                    if (picked != null) setState(() => _walletId = picked);
                  },
                ),
            ]),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Tiến độ ${goal.name}', 'Progress of ${goal.name}'), style: TichiText.label),
                    const SizedBox(height: 10),
                    _ProgressRow(
                      label: tr('Trước', 'Before'),
                      value: '${formatMinor(goal.savedMinor, c)} · $beforePercent%',
                      percent: beforePercent,
                    ),
                    const SizedBox(height: 10),
                    _ProgressRow(
                      label: tr('Sau', 'After'),
                      value: '${formatMinor(after < 0 ? 0 : after, c)} · $afterPercent%',
                      percent: afterPercent,
                      color: _mode == SavingsMode.withdraw
                          ? TichiColors.warning
                          : TichiColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: TichiColors.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(explain, style: TichiText.caption)),
              ],
            ),
            if (_error != null) FormError(_error!),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('move-confirm'),
              onPressed: _saving ? null : () => _confirm(store, goal),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.percent,
    this.color,
  });

  final String label;
  final String value;
  final int percent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(percent: percent, color: color),
      ],
    );
  }
}

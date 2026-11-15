/// Chi tiết một mục tiêu: tiến độ, số nên tiết kiệm, lịch sử, các nút Tiết
/// kiệm ngay và Rút tiền.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import '../core/savings/savings_center.dart';
import 'goal_form_screen.dart';
import 'icons.dart';
import 'savings_move_screen.dart';
import 'widgets.dart';
import '../core/l10n.dart';

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  Future<void> _delete(BuildContext context, GoalProgress goal) async {
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: tr('Xóa mục tiêu?', 'Delete goal?'),
      message: goal.savedMinor > 0
          ? tr('${formatMinor(goal.savedMinor, goal.currencyCode)} vẫn nằm trong '
              'ví tiết kiệm và trở thành "Chưa gắn mục tiêu". Lịch sử giao '
              'dịch được giữ lại.', '${formatMinor(goal.savedMinor, goal.currencyCode)} stays in the ' 'savings wallet and becomes "Unassigned". Transaction history ' 'is kept.')
          : tr('Lịch sử giao dịch được giữ lại.', 'Transaction history is kept.'),
      confirmLabel: tr('Xóa', 'Delete'),
    );
    if (!ok) return;
    try {
      store.deleteGoal(goal.goalId);
      navigator.pop();
    } on FinanceException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final GoalProgress goal;
    try {
      goal = store.goal(goalId);
    } on FinanceException {
      // Mục tiêu vừa bị xóa; màn hình sắp đóng.
      return const Scaffold();
    }
    final now = DateTime.now();
    final suggestion = store.suggestion(goalId, now);
    final history = store.goalHistory(goalId);
    final vault = store.wallet(goal.savingsWalletId);
    final c = goal.currencyCode;

    void open(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: tr('Sửa mục tiêu', 'Edit goal'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => open(GoalFormScreen(goalId: goalId)),
          ),
          IconButton(
            tooltip: tr('Xóa mục tiêu', 'Delete goal'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, goal),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconAvatar(
                                  icon: goal.icon, color: 'emerald', size: 44),
                              const SizedBox(width: 12),
                              Text('${goal.percent}%',
                                  style: TextStyle(
                                      fontSize: 40,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                      color: TichiColors.primary)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                          formatMinor(goal.savedMinor, c),
                                          style: TichiText.amount),
                                    ),
                                    Text(
                                        tr('trên ${formatMinor(goal.targetMinor, c)}', 'of ${formatMinor(goal.targetMinor, c)}'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TichiText.label),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ProgressBar(percent: goal.percent, height: 10),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    goal.remainingMinor > 0
                                        ? tr('Còn thiếu ${formatMinor(goal.remainingMinor, c)}', '${formatMinor(goal.remainingMinor, c)} to go')
                                        : tr('Đã đủ tiền', 'Goal reached'),
                                    style: TichiText.caption),
                              ),
                              Text(tr('Hạn ${shortDate(goal.targetDate)}', 'Due ${shortDate(goal.targetDate)}'),
                                  style: TichiText.caption),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                  child: Text(tr('Tiền nằm trong', 'Money kept in'),
                                      style: TichiText.caption)),
                              Text(vault.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (suggestion != null) ...[
                    FieldLabel(
                        tr('Để kịp hạn (còn ${suggestion.daysLeft} ngày), nên tiết kiệm khoảng', 'To make it on time (${suggestion.daysLeft} days left), save about')),
                    Row(
                      children: [
                        Expanded(
                            child: _SuggestionTile(
                                label: tr('Mỗi ngày', 'Daily'),
                                value: formatMinor(suggestion.dailyMinor, c),
                                highlight: true)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _SuggestionTile(
                                label: tr('Mỗi tuần', 'Weekly'),
                                value: formatMinor(suggestion.weeklyMinor, c))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _SuggestionTile(
                                label: tr('Mỗi tháng', 'Monthly'),
                                value: formatMinor(suggestion.monthlyMinor, c))),
                      ],
                    ),
                  ] else
                    Text(
                        goal.remainingMinor <= 0
                            ? tr('Mục tiêu đã đủ tiền.', 'This goal is fully funded.')
                            : tr('Đã quá hạn. Sửa ngày hoàn thành để có số gợi ý mới.', 'Past the due date. Change the target date to get a new suggestion.'),
                        style: TichiText.caption),
                  const SizedBox(height: 20),
                  FieldLabel(tr('Lịch sử', 'History')),
                  if (history.isEmpty)
                    Text(tr('Chưa có lần tiết kiệm nào.', 'No savings yet.'),
                        style: TichiText.caption)
                  else
                    GroupCard(children: [
                      for (final event in history)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(dayLabel(event.date, now),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    Text(_eventLabel(event, vault.name),
                                        style: TichiText.label),
                                  ],
                                ),
                              ),
                              Text(
                                formatMinor(event.amountMinor, c,
                                    showPlus: true),
                                style: TichiText.amount.copyWith(
                                    fontSize: 14,
                                    color: event.amountMinor > 0
                                        ? TichiColors.primary
                                        : TichiColors.ink),
                              ),
                            ],
                          ),
                        ),
                    ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: goal.savedMinor <= 0
                          ? null
                          : () => open(SavingsMoveScreen(
                              mode: SavingsMode.withdraw, goalId: goalId)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: TichiColors.primary,
                        side: BorderSide(color: TichiColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(tr('Rút tiền', 'Withdraw')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: goal.status == 'ARCHIVED'
                          ? null
                          : () => open(SavingsMoveScreen(
                              mode: SavingsMode.contribute, goalId: goalId)),
                      child: Text(tr('Tiết kiệm ngay', 'Save now')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _eventLabel(GoalEvent event, String vaultName) => switch (event.kind) {
      'ALLOCATION' => tr('Chia từ tiền có sẵn trong $vaultName', 'Assigned from money already in $vaultName'),
      'WITHDRAWAL' => tr('Rút về ${event.walletName ?? 'ví'}', 'Withdrawn to ${event.walletName ?? 'wallet'}'),
      _ => tr('Từ ${event.walletName ?? 'ví'} → $vaultName', 'From ${event.walletName ?? 'wallet'} › $vaultName'),
    };

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile(
      {required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? TichiColors.primarySoft : TichiColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: highlight
                      ? TichiColors.softText
                      : TichiColors.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: highlight ? TichiColors.primary : TichiColors.ink)),
          ),
        ],
      ),
    );
  }
}

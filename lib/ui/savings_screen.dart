/// Tiết kiệm: tổng trong ví tiết kiệm, chuỗi ngày, gợi ý hôm nay, các mục
/// tiêu và phần tiền chưa gắn mục tiêu.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/money.dart';
import '../core/savings/savings_center.dart';
import 'goal_detail_screen.dart';
import 'goal_form_screen.dart';
import 'icons.dart';
import 'savings_move_screen.dart';
import 'wallet_form_screen.dart';
import 'widgets.dart';
import '../core/l10n.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final base = store.baseCurrency;
    final vaults = store.savingsWallets();
    final goals = store.goals();
    final active = goals.where((g) => g.status != 'ARCHIVED').toList();

    var totalSaved = 0;
    var missingRate = false;
    for (final vault in vaults) {
      final value = store.toBase(vault.balanceMinor, vault.currencyCode);
      if (value == null) {
        missingRate = true;
      } else {
        totalSaved += value;
      }
    }
    var totalTarget = 0;
    for (final goal in active) {
      totalTarget += store.toBase(goal.targetMinor, goal.currencyCode) ?? 0;
    }
    final focus = _firstActive(active);
    final suggestion =
        focus == null ? null : store.suggestion(focus.goalId, now);
    final streak = store.streak(now);

    void open(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(tr('Tiết kiệm', 'Savings'), style: TichiText.pageTitle)),
              if (goals.isNotEmpty)
                OutlinedButton(
                  onPressed: () => open(
                      const SavingsMoveScreen(mode: SavingsMode.withdraw)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: TichiColors.primary,
                      side: BorderSide(color: TichiColors.primary)),
                  child: Text(tr('Rút tiền', 'Withdraw')),
                ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: tr('Tạo mục tiêu mới', 'Create a new goal'),
                onPressed: vaults.isEmpty
                    ? null
                    : () => open(const GoalFormScreen()),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (vaults.isEmpty)
            EmptyState(
              icon: 'coins',
              message:
                  tr('Bạn chưa có ví tiết kiệm. Tạo một ví tiết kiệm để bắt đầu '
                  'đặt mục tiêu.', 'You don\'t have a savings wallet yet. Create one to start ' 'setting goals.'),
              actionLabel: tr('Tạo ví tiết kiệm', 'Create savings wallet'),
              onAction: () =>
                  open(const WalletFormScreen(initialType: 'SAVINGS')),
            )
          else ...[
            _SummaryCard(
              totalSaved: totalSaved,
              base: base,
              goalCount: active.length,
              totalTarget: totalTarget,
              streak: streak,
              frequency: store.reminderFrequency,
              missingRate: missingRate,
            ),
            if (focus != null && suggestion != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Gợi ý hôm nay', 'Today\'s suggestion'),
                                style: TichiText.label),
                            const SizedBox(height: 2),
                            Text(
                              '${formatMinor(suggestion.dailyMinor, focus.currencyCode)} '
                              'cho ${focus.name}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44)),
                        onPressed: () => open(SavingsMoveScreen(
                            mode: SavingsMode.contribute,
                            goalId: focus.goalId)),
                        child: Text(tr('Tiết kiệm', 'Savings')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            for (final vault in vaults)
              if (store.unallocated(vault.id) > 0) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: IconAvatar(icon: vault.icon, color: vault.color),
                    title: Text(
                        tr('Chưa gắn mục tiêu: '
                        '${formatMinor(store.unallocated(vault.id), vault.currencyCode)}', 'Unassigned: ' '${formatMinor(store.unallocated(vault.id), vault.currencyCode)}'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(tr('Trong ${vault.name}', 'In ${vault.name}')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: goals.isEmpty
                        ? null
                        : () => open(SavingsMoveScreen(
                            mode: SavingsMode.allocate,
                            savingsWalletId: vault.id)),
                  ),
                ),
              ],
            const SizedBox(height: 20),
            Text(tr('Mục tiêu của bạn', 'Your goals'), style: TichiText.section),
            const SizedBox(height: 8),
            if (goals.isEmpty)
              EmptyState(
                icon: 'savings',
                message: tr('Chưa có mục tiêu nào. Đặt mục tiêu đầu tiên, Tichi '
                    'sẽ tính mỗi ngày cần để dành bao nhiêu.', 'No goals yet. Set your first goal and Tichi ' 'will work out how much to save each day.'),
                actionLabel: tr('Tạo mục tiêu', 'Create goal'),
                onAction: () => open(const GoalFormScreen()),
              ),
            for (final goal in goals) ...[
              _GoalCard(
                goal: goal,
                onTap: () => open(GoalDetailScreen(goalId: goal.goalId)),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalSaved,
    required this.base,
    required this.goalCount,
    required this.totalTarget,
    required this.streak,
    required this.frequency,
    required this.missingRate,
  });

  final int totalSaved;
  final String base;
  final int goalCount;
  final int totalTarget;
  final int streak;

  /// Chuỗi đếm theo ngày, tuần hay tháng, theo tần suất nhắc tiết kiệm.
  final String frequency;
  final bool missingRate;

  @override
  Widget build(BuildContext context) {
    final light = TextStyle(fontSize: 12, color: TichiColors.onPrimaryMuted);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TichiColors.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Tổng trong ví tiết kiệm', 'Total in savings wallets'),
                    style: TextStyle(
                        fontSize: 13, color: TichiColors.onPrimaryMuted)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatMinor(totalSaved, base),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                const SizedBox(height: 4),
                Text(
                  goalCount == 0
                      ? tr('Chưa có mục tiêu', 'No goals yet')
                      : tr('$goalCount mục tiêu · tổng cần ${formatMinor(totalTarget, base)}', '$goalCount goals · ${formatMinor(totalTarget, base)} needed in total'),
                  style: light,
                ),
                if (missingRate)
                  Text(tr('Chưa tính ví USD vì chưa có tỷ giá', 'USD wallets not included: no exchange rate yet'),
                      style: light),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  switch (frequency) {
                    'weekly' => tr('$streak tuần', '$streak weeks'),
                    'monthly' => tr('$streak tháng', '$streak months'),
                    _ => tr('$streak ngày', '$streak days'),
                  },
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text(tr('liên tiếp', 'in a row'), style: light),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final GoalProgress goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = goal.status == 'COMPLETED';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconAvatar(icon: goal.icon, color: 'emerald', size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Text(done ? tr('Hoàn thành', 'Completed') : '${goal.percent}%',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: TichiColors.primary)),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(percent: goal.percent),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatMinor(goal.savedMinor, goal.currencyCode)} / '
                      '${formatMinor(goal.targetMinor, goal.currencyCode)}',
                      style: TichiText.label,
                    ),
                  ),
                  Text(tr('Hạn ${shortDate(goal.targetDate)}', 'Due ${shortDate(goal.targetDate)}'),
                      style: TichiText.label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

GoalProgress? _firstActive(List<GoalProgress> goals) {
  for (final goal in goals) {
    if (goal.status == 'ACTIVE') return goal;
  }
  return null;
}

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
                  child: Text('Tiết kiệm', style: TichiText.pageTitle)),
              if (goals.isNotEmpty)
                OutlinedButton(
                  onPressed: () => open(
                      const SavingsMoveScreen(mode: SavingsMode.withdraw)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: TichiColors.primary,
                      side: BorderSide(color: TichiColors.primary)),
                  child: const Text('Rút tiền'),
                ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Tạo mục tiêu mới',
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
                  'Bạn chưa có ví tiết kiệm. Tạo một ví tiết kiệm để bắt đầu '
                  'đặt mục tiêu.',
              actionLabel: 'Tạo ví tiết kiệm',
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
                            Text('Gợi ý hôm nay',
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
                        child: const Text('Tiết kiệm'),
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
                        'Chưa gắn mục tiêu: '
                        '${formatMinor(store.unallocated(vault.id), vault.currencyCode)}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Trong ${vault.name}'),
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
            Text('Mục tiêu của bạn', style: TichiText.section),
            const SizedBox(height: 8),
            if (goals.isEmpty)
              EmptyState(
                icon: 'savings',
                message: 'Chưa có mục tiêu nào. Đặt mục tiêu đầu tiên, Tichi '
                    'sẽ tính mỗi ngày cần để dành bao nhiêu.',
                actionLabel: 'Tạo mục tiêu',
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
    required this.missingRate,
  });

  final int totalSaved;
  final String base;
  final int goalCount;
  final int totalTarget;
  final int streak;
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
                Text('Tổng trong ví tiết kiệm',
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
                      ? 'Chưa có mục tiêu'
                      : '$goalCount mục tiêu · tổng cần ${formatMinor(totalTarget, base)}',
                  style: light,
                ),
                if (missingRate)
                  Text('Chưa tính ví USD vì chưa có tỷ giá',
                      style: light),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$streak ngày',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text('liên tiếp', style: light),
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
                  Text(done ? 'Hoàn thành' : '${goal.percent}%',
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
                  Text('Hạn ${shortDate(goal.targetDate)}',
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

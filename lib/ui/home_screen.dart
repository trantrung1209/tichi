/// Trang chủ: tổng tài sản quy về một loại tiền, thu chi tháng, gợi ý tiết
/// kiệm và giao dịch gần đây.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/money.dart';
import 'goal_detail_screen.dart';
import 'icons.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSeeAllTransactions});

  final VoidCallback onSeeAllTransactions;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final summary = store.homeSummary(now);
    final base = summary.baseCurrency;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          Text(monthLabel(now.year, now.month), style: TichiText.caption),
          const SizedBox(height: 2),
          Text('Tổng quan', style: TichiText.pageTitle),
          const SizedBox(height: 16),
          if (summary.missingRate) ...[
            _RateBanner(onTap: () => showRateDialog(context)),
            const SizedBox(height: 12),
          ],
          _AssetCard(summary: summary),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallStat(
                  label: 'Thu tháng này',
                  value: formatMinor(summary.incomeMinor, base, showPlus: true),
                  color: TichiColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallStat(
                  label: 'Chi tháng này',
                  value: formatMinor(-summary.expenseMinor, base),
                  color: TichiColors.ink,
                ),
              ),
            ],
          ),
          if (summary.goal != null) ...[
            const SizedBox(height: 12),
            _GoalCard(summary: summary),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: Text('Giao dịch gần đây', style: TichiText.section)),
              TextButton(
                onPressed: onSeeAllTransactions,
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          if (summary.recent.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chưa có giao dịch. Bấm nút + để ghi khoản đầu tiên.',
                  style: TichiText.caption,
                ),
              ),
            )
          else
            GroupCard(children: [
              for (final tx in summary.recent) TransactionTile(tx: tx),
            ]),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final base = summary.baseCurrency;
    final light = TextStyle(fontSize: 12, color: TichiColors.onPrimaryMuted);
    const value =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TichiColors.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tổng tài sản',
              style: TextStyle(fontSize: 13, color: TichiColors.onPrimaryMuted)),
          const SizedBox(height: 4),
          Text(
            formatMinor(summary.totalMinor, base),
            key: const Key('total-assets'),
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0x2EFFFFFF)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trong ví tiết kiệm', style: light),
                    const SizedBox(height: 2),
                    Text(formatMinor(summary.savingsMinor, base), style: value),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trong ví chi tiêu', style: light),
                    const SizedBox(height: 2),
                    Text(formatMinor(summary.spendingMinor, base),
                        style: value),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TichiText.label),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TichiText.amount.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final goal = summary.goal!;
    final suggestion = summary.suggestion;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => GoalDetailScreen(goalId: goal.goalId))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconAvatar(icon: goal.icon, color: 'emerald', size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(goal.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Text('${goal.percent}%', style: TichiText.caption),
                ],
              ),
              const SizedBox(height: 8),
              ProgressBar(percent: goal.percent),
              const SizedBox(height: 8),
              Text(
                suggestion == null
                    ? 'Đã quá hạn hoặc đã đủ tiền.'
                    : 'Hôm nay nên tiết kiệm '
                        '${formatMinor(suggestion.dailyMinor, goal.currencyCode)}',
                style: TichiText.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateBanner extends StatelessWidget {
  const _RateBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TichiColors.warningSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.currency_exchange, color: TichiColors.warningText),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bạn có tiền USD nhưng chưa nhập tỷ giá, nên các tổng dưới '
                  'đây chưa tính phần USD. Bấm để nhập tỷ giá.',
                  style: TextStyle(
                      fontSize: 13, color: TichiColors.warningText, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trang chủ: tổng tài sản quy về một loại tiền, thu chi tháng, gợi ý tiết
/// kiệm và giao dịch gần đây.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../core/finance/money.dart';
import 'add_transaction_screen.dart';
import 'backup_screen.dart';
import 'goal_detail_screen.dart';
import 'icons.dart';
import 'widgets.dart';
import '../core/l10n.dart';

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
          _Greeting(name: store.userName, now: now),
          const SizedBox(height: 16),
          if (store.backupDue(now)) ...[
            _BackupBanner(
              lastBackupAt: store.lastBackupAt,
              onBackup: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const BackupScreen())),
              onLater: () => store.snoozeBackupReminder(now),
            ),
            const SizedBox(height: 12),
          ],
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
                  label: tr('Thu tháng này', 'Income this month'),
                  value: formatMinor(summary.incomeMinor, base, showPlus: true),
                  color: TichiColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallStat(
                  label: tr('Chi tháng này', 'Spent this month'),
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
                  child: Text(tr('Giao dịch gần đây', 'Recent transactions'), style: TichiText.section)),
              TextButton(
                onPressed: onSeeAllTransactions,
                child: Text(tr('Xem tất cả', 'See all')),
              ),
            ],
          ),
          if (summary.recent.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  tr('Chưa có giao dịch. Bấm nút + để ghi khoản đầu tiên.', 'No transactions yet. Tap + to add your first one.'),
                  style: TichiText.caption,
                ),
              ),
            )
          else
            GroupCard(children: [
              for (final tx in summary.recent)
                InkWell(
                  onTap: () => openTransaction(context, tx),
                  child: TransactionTile(tx: tx),
                ),
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
          Text(tr('Tổng tài sản', 'Total balance'),
              style: TextStyle(fontSize: 13, color: TichiColors.onPrimaryMuted)),
          const SizedBox(height: 4),
          AnimatedAmount(
            minor: summary.totalMinor,
            currency: base,
            textKey: const Key('total-assets'),
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()]),
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
                    Text(tr('Trong ví tiết kiệm', 'In savings wallets'), style: light),
                    const SizedBox(height: 2),
                    Text(formatMinor(summary.savingsMinor, base), style: value),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Trong ví chi tiêu', 'In spending wallets'), style: light),
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
                    ? tr('Đã quá hạn hoặc đã đủ tiền.', 'Past due or fully funded.')
                    : tr('Hôm nay nên tiết kiệm '
                        '${formatMinor(suggestion.dailyMinor, goal.currencyCode)}', 'Save today: ' '${formatMinor(suggestion.dailyMinor, goal.currencyCode)}'),
                style: TichiText.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhắc sao lưu: dữ liệu chỉ nằm trên máy nên cần một bản dự phòng.
/// Lời chào ở đầu Trang chủ: tên gọi của người dùng, câu chúc theo giờ và
/// tháng đang xem. Tên dài thì cắt bớt, không làm vỡ bố cục.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.now});

  final String? name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home-greeting'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${TichiStrings.timeGreeting(now)} · ${monthLabel(now.year, now.month)}',
          style: TichiText.caption,
        ),
        const SizedBox(height: 2),
        Text(
          TichiStrings.hello(name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TichiText.pageTitle,
        ),
      ],
    );
  }
}

class _BackupBanner extends StatelessWidget {
  const _BackupBanner({
    required this.lastBackupAt,
    required this.onBackup,
    required this.onLater,
  });

  final String? lastBackupAt;
  final VoidCallback onBackup;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final last = lastBackupAt;
    return Card(
      key: const Key('backup-banner'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconAvatar(icon: 'insurance', color: 'green', size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          last == null
                              ? tr('Bạn chưa sao lưu lần nào', 'You haven\'t backed up yet')
                              : tr('Đã lâu chưa sao lưu', 'It\'s been a while since your last backup'),
                          style: TichiText.section),
                      const SizedBox(height: 2),
                      Text(
                        last == null
                            ? tr('Dữ liệu chỉ nằm trên máy này. Mất máy hay cài '
                                'lại app mà chưa sao lưu là mất hết.', 'Your data only lives on this phone. Lose the phone or reinstall ' 'the app without a backup and it\'s gone.')
                            : tr('Lần gần nhất ngày ${shortDate(last)}. Sao lưu '
                                'lại để giữ cả những giao dịch mới.', 'Last backup on ${shortDate(last)}. Back up again ' 'to keep your newer transactions.'),
                        style: TichiText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('backup-later'),
                  onPressed: onLater,
                  child: Text(tr('Để sau', 'Later')),
                ),
                TextButton(
                  onPressed: onBackup,
                  child: Text(tr('Sao lưu ngay', 'Back up now')),
                ),
              ],
            ),
          ],
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
                  tr('Bạn có tiền USD nhưng chưa nhập tỷ giá, nên các tổng dưới '
                  'đây chưa tính phần USD. Bấm để nhập tỷ giá.', 'You have USD but no exchange rate yet, so the totals below ' 'don\'t include USD. Tap to enter a rate.'),
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

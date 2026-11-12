/// Danh sách giao dịch theo tháng, nhóm theo ngày. Vuốt sang trái để xóa,
/// có nút Hoàn tác.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import 'widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<bool> _delete(TransactionView tx) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      store.deleteTransaction(tx.id);
    } on FinanceException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(error))));
      return false;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Đã xóa giao dịch'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            try {
              store.restoreTransaction(tx.id);
            } on FinanceException catch (error) {
              messenger.showSnackBar(
                  SnackBar(content: Text(friendlyError(error))));
            }
          },
        ),
      ));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final prefix = dateKey(_month).substring(0, 7);
    final totals = store.monthTotals(_month.year, _month.month);
    final items = store.transactions(monthPrefix: prefix);
    final base = store.baseCurrency;
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    final groups = <String, List<TransactionView>>{};
    for (final tx in items) {
      groups.putIfAbsent(tx.date, () => []).add(tx);
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          Text('Giao dịch', style: TichiText.pageTitle),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Tháng trước',
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  monthLabel(_month.year, _month.month),
                  textAlign: TextAlign.center,
                  style: TichiText.section,
                ),
              ),
              IconButton(
                tooltip: 'Tháng sau',
                onPressed: isCurrentMonth ? null : () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _Total(
                      label: 'Thu',
                      value: formatMinor(totals.incomeMinor, base,
                          showPlus: true),
                      color: TichiColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _Total(
                      label: 'Chi',
                      value: formatMinor(-totals.expenseMinor, base),
                      color: TichiColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Tháng này chưa có giao dịch.',
                  textAlign: TextAlign.center, style: TichiText.caption),
            ),
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
              child: Text(dayLabel(entry.key, now),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TichiColors.muted)),
            ),
            GroupCard(children: [
              for (final tx in entry.value)
                Dismissible(
                  key: ValueKey(tx.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _delete(tx),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.delete_outline,
                        color: TichiColors.danger),
                  ),
                  child: TransactionTile(tx: tx),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TichiText.label),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TichiText.amount.copyWith(color: color)),
        ),
      ],
    );
  }
}

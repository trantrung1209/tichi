/// Ngân sách tháng: tổng cả tháng và từng danh mục, có cảnh báo 80% và 100%.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/budget/budget_service.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import 'icons.dart';
import 'widgets.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final base = store.baseCurrency;
    final statuses = store.budgetStatuses(now.year, now.month);
    final overall = _overall(statuses);
    final byCategory = statuses.where((s) => !s.isOverall).toList();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day + 1;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(monthLabel(now.year, now.month),
                        style: TichiText.caption),
                    const SizedBox(height: 2),
                    Text('Ngân sách', style: TichiText.pageTitle),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Thêm ngân sách',
                onPressed: () => showBudgetSheet(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (statuses.isEmpty)
            EmptyState(
              icon: 'budget',
              message: 'Đặt một mức chi cho cả tháng hoặc cho từng danh mục. '
                  'Tichi sẽ cho bạn biết khi đã dùng 80% và khi vượt mức.',
              actionLabel: 'Đặt ngân sách',
              onAction: () => showBudgetSheet(context),
            ),
          if (overall != null)
            _OverallCard(
              status: overall,
              base: base,
              daysLeft: daysLeft,
              onTap: () => showBudgetSheet(context, existing: overall),
            ),
          if (byCategory.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Theo danh mục', style: TichiText.section),
            const SizedBox(height: 8),
            GroupCard(children: [
              for (final status in byCategory)
                InkWell(
                  onTap: () => showBudgetSheet(context, existing: status),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        IconAvatar(icon: status.icon, color: status.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(status.name,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  Text(_levelText(status),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _levelTextColor(status.level))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ProgressBar(
                                  percent: status.percent,
                                  height: 6,
                                  color: budgetColor(status.level)),
                              const SizedBox(height: 4),
                              Text(
                                  '${formatMinor(status.spentMinor, base)} / '
                                  '${formatMinor(status.limitMinor, base)}',
                                  style: TichiText.label),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 16),
          Text(
              'Ngân sách tính các khoản chi trong tháng từ ví cùng loại tiền '
              'hiển thị. Chuyển ví và tiết kiệm không bị tính.',
              style: TichiText.label),
        ],
      ),
    );
  }
}

BudgetStatus? _overall(List<BudgetStatus> statuses) {
  for (final status in statuses) {
    if (status.isOverall) return status;
  }
  return null;
}

String _levelText(BudgetStatus status) => switch (status.level) {
      'over' => 'Vượt ${status.percent - 100}%',
      'warning' => 'Sắp chạm · ${status.percent}%',
      _ => '${status.percent}%',
    };

Color _levelTextColor(String level) => switch (level) {
      'over' => TichiColors.danger,
      'warning' => TichiColors.warningText,
      _ => TichiColors.muted,
    };

class _OverallCard extends StatelessWidget {
  const _OverallCard({
    required this.status,
    required this.base,
    required this.daysLeft,
    required this.onTap,
  });

  final BudgetStatus status;
  final String base;
  final int daysLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = status.remainingMinor;
    final perDay = remaining > 0 ? remaining ~/ daysLeft : 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(remaining >= 0 ? 'Còn lại trong tháng' : 'Đã vượt ngân sách',
                  style: TichiText.caption),
              const SizedBox(height: 4),
              Text(formatMinor(remaining.abs(), base),
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: remaining >= 0
                          ? TichiColors.ink
                          : TichiColors.danger)),
              const SizedBox(height: 12),
              ProgressBar(
                  percent: status.percent,
                  height: 10,
                  color: budgetColor(status.level)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'Đã chi ${formatMinor(status.spentMinor, base)} / '
                        '${formatMinor(status.limitMinor, base)}',
                        style: TichiText.caption),
                  ),
                  Text(_levelText(status),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _levelTextColor(status.level))),
                ],
              ),
              if (remaining > 0) ...[
                const Divider(height: 24),
                Text(
                    'Còn $daysLeft ngày. Nên chi dưới '
                    '${formatMinor(perDay, base)} mỗi ngày để không vượt.',
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng đặt hoặc sửa ngân sách. [existing] null là thêm mới.
Future<void> showBudgetSheet(BuildContext context,
    {BudgetStatus? existing}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BudgetSheet(existing: existing),
  );
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({this.existing});

  final BudgetStatus? existing;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  final _amount = TextEditingController();

  /// Null là ngân sách tổng cả tháng.
  String? _categoryId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _categoryId = existing.categoryId;
      _amount.text = amountText(existing.limitMinor, existing.currencyCode);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final store = StoreScope.read(context);
    final amount = parseMinor(_amount.text, store.baseCurrency);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Nhập số tiền lớn hơn 0.');
      return;
    }
    try {
      store.setBudget(categoryId: _categoryId, amountMinor: amount);
    } on FinanceException catch (error) {
      setState(() => _error = friendlyError(error));
      return;
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    final existing = widget.existing;
    if (existing == null) return;
    StoreScope.read(context).deleteBudget(existing.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final categories = store.categories('EXPENSE');
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEdit ? 'Sửa ngân sách' : 'Đặt ngân sách tháng',
                  style: TichiText.section),
              const SizedBox(height: 12),
              const FieldLabel('Áp dụng cho'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.pie_chart, size: 18),
                    label: const Text('Cả tháng'),
                    selected: _categoryId == null,
                    showCheckmark: false,
                    onSelected:
                        isEdit ? null : (_) => setState(() => _categoryId = null),
                  ),
                  for (final category in categories)
                    ChoiceChip(
                      avatar: Icon(iconFor(category.icon), size: 18),
                      label: Text(category.name),
                      selected: _categoryId == category.id,
                      showCheckmark: false,
                      onSelected: isEdit
                          ? null
                          : (_) => setState(() => _categoryId = category.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AmountInput(
                fieldKey: const Key('budget-amount'),
                controller: _amount,
                currency: store.baseCurrency,
                autofocus: !isEdit,
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null) FormError(_error!),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Lưu')),
              if (isEdit) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                      foregroundColor: TichiColors.danger,
                      minimumSize: const Size.fromHeight(48)),
                  child: const Text('Xóa ngân sách này'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

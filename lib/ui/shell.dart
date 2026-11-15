/// Khung chính: thanh điều hướng dưới với 5 mục và nút thêm giao dịch.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/strings.dart';

import 'add_transaction_screen.dart';
import 'budgets_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'savings_screen.dart';
import 'transactions_screen.dart';
import '../core/l10n.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  DateTime? _lastBack;

  /// Hiệu ứng chuyển tab: tab mới hiện dần và trượt lên rất nhẹ.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _fade, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
    _fade.forward(from: 0);
  }

  /// Nút quay lại ở màn hình chính: đang ở tab khác thì về Trang chủ; ở
  /// Trang chủ thì phải nhấn hai lần trong 2 giây mới thoát app.
  void _handleBack() {
    if (_index != 0) {
      _select(0);
      return;
    }
    final now = DateTime.now();
    final last = _lastBack;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(TichiStrings.pressBackAgain),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final showAddButton = _index == 0 || _index == 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      body: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: IndexedStack(
            index: _index,
            children: [
              HomeScreen(onSeeAllTransactions: () => _select(1)),
              const TransactionsScreen(),
              const BudgetsScreen(),
              const SavingsScreen(),
              const MoreScreen(),
            ],
          ),
        ),
      ),
      floatingActionButton: showAddButton
          ? FloatingActionButton(
              tooltip: tr('Thêm giao dịch', 'Add transaction'),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const AddTransactionScreen()));
              },
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: tr('Trang chủ', 'Home')),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: tr('Giao dịch', 'Transactions')),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: tr('Ngân sách', 'Budgets')),
          NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings),
              label: tr('Tiết kiệm', 'Savings')),
          NavigationDestination(
              icon: Icon(Icons.more_horiz), label: tr('Thêm', 'More')),
        ],
      ),
    ),
    );
  }
}

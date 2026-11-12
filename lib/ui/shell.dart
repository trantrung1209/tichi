/// Khung chính: thanh điều hướng dưới với 5 mục và nút thêm giao dịch.
library;

import 'package:flutter/material.dart';

import 'add_transaction_screen.dart';
import 'budgets_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'savings_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final showAddButton = _index == 0 || _index == 1;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onSeeAllTransactions: () => _select(1)),
          const TransactionsScreen(),
          const BudgetsScreen(),
          const SavingsScreen(),
          const MoreScreen(),
        ],
      ),
      floatingActionButton: showAddButton
          ? FloatingActionButton(
              tooltip: 'Thêm giao dịch',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const AddTransactionScreen())),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Trang chủ'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Giao dịch'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: 'Ngân sách'),
          NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings),
              label: 'Tiết kiệm'),
          NavigationDestination(
              icon: Icon(Icons.more_horiz), label: 'Thêm'),
        ],
      ),
    );
  }
}

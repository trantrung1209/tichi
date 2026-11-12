/// Hướng dẫn lần đầu dùng app: 3 trang giới thiệu và 1 trang nhập số dư hiện
/// có. Xem lại được từ mục Thêm.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import 'brand.dart';
import 'icons.dart';
import 'widgets.dart';

class OnboardingScreen extends StatefulWidget {
  /// [replay] true khi người dùng mở lại từ mục Thêm: bỏ trang nhập số dư.
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final Map<String, TextEditingController> _balances = {};
  int _page = 0;
  bool _remind = true;
  String? _error;

  int get _pageCount => widget.replay ? 3 : 4;

  @override
  void dispose() {
    _pages.dispose();
    for (final controller in _balances.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pages.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final store = StoreScope.read(context);
    if (widget.replay) {
      Navigator.of(context).pop();
      return;
    }
    try {
      for (final wallet in store.spendingWallets()) {
        final text = _balances[wallet.id]?.text.trim() ?? '';
        if (text.isEmpty) continue;
        final amount = parseMinor(text, wallet.currencyCode);
        if (amount == null) {
          setState(() => _error = 'Số dư của ${wallet.name} không hợp lệ.');
          return;
        }
        store.setOpeningBalance(wallet.id, amount);
      }
    } on FinanceException catch (error) {
      setState(() => _error = friendlyError(error));
      return;
    }
    if (_remind) await store.setReminder(enabled: true);
    store.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isLast = _page == _pageCount - 1;
    final pages = <Widget>[
      const _IntroPage(
        hero: TichiAppIcon(size: 96),
        title: 'Chào mừng đến Tichi',
        lead: 'Tích từng chút, thành điều lớn.',
        points: [
          ('wallet', 'Không cần tài khoản', 'Mở app là dùng được ngay.'),
          ('internet', 'Không cần Internet', 'Mọi tính năng chạy ngay trên máy.'),
          ('insurance', 'Dữ liệu là của bạn',
              'Chỉ nằm trên điện thoại này. Không quảng cáo, không theo dõi.'),
        ],
      ),
      const _IntroPage(
        hero: IconAvatar(icon: 'bills', color: 'blue', size: 96),
        title: 'Ghi thu chi trong vài giây',
        lead: 'Bấm nút + ở Trang chủ, nhập số tiền, chọn danh mục và ví.',
        points: [
          ('transfer', 'Chuyển giữa các ví',
              'Rút tiền ATM hay nạp ví điện tử là chuyển ví, không tính là chi.'),
          ('more', 'Vuốt sang trái để xóa', 'Lỡ tay thì bấm Hoàn tác.'),
          ('budget', 'Đặt ngân sách tháng',
              'Tichi báo khi bạn đã dùng 80% và khi vượt mức.'),
        ],
      ),
      const _IntroPage(
        hero: IconAvatar(icon: 'savings', color: 'gold', size: 96),
        title: 'Tiết kiệm bằng tiền thật',
        lead: 'Mỗi lần tiết kiệm là chuyển tiền thật vào ví tiết kiệm, '
            'không phải con số ảo.',
        points: [
          ('travel', 'Đặt mục tiêu', 'Du lịch, điện thoại mới, quỹ dự phòng...'),
          ('coins', 'Biết mỗi ngày cần bao nhiêu',
              'Tichi tính số nên dành mỗi ngày để kịp hạn.'),
          ('bonus', 'Giữ chuỗi ngày',
              'Bỏ một hôm cũng không sao, cứ tiếp tục là được.'),
        ],
      ),
      if (!widget.replay)
        _BalancePage(
          wallets: store.spendingWallets(),
          controllers: _balances,
          remind: _remind,
          onRemind: (value) => setState(() => _remind = value),
          error: _error,
        ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: TextButton(
                  onPressed: isLast
                      ? null
                      : () => _pages.animateToPage(_pageCount - 1,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOut),
                  child: Text(isLast ? '' : 'Bỏ qua'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (index) => setState(() => _page = index),
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pageCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          i == _page ? TichiColors.primary : TichiColors.track,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: FilledButton(
                key: const Key('onboarding-next'),
                onPressed: _next,
                child: Text(isLast
                    ? (widget.replay ? 'Đã hiểu' : 'Bắt đầu dùng Tichi')
                    : 'Tiếp'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.hero,
    required this.title,
    required this.lead,
    required this.points,
  });

  final Widget hero;
  final String title;
  final String lead;

  /// (biểu tượng, tiêu đề, mô tả)
  final List<(String, String, String)> points;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        Center(child: hero),
        const SizedBox(height: 28),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.2)),
        const SizedBox(height: 10),
        Text(lead,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, height: 1.5, color: TichiColors.muted)),
        const SizedBox(height: 28),
        for (final (icon, heading, detail) in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconAvatar(icon: icon, color: 'emerald', size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(detail,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: TichiColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BalancePage extends StatelessWidget {
  const _BalancePage({
    required this.wallets,
    required this.controllers,
    required this.remind,
    required this.onRemind,
    required this.error,
  });

  final List<WalletInfo> wallets;
  final Map<String, TextEditingController> controllers;
  final bool remind;
  final ValueChanged<bool> onRemind;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        const Center(
            child: IconAvatar(icon: 'cash', color: 'green', size: 96)),
        const SizedBox(height: 28),
        const Text('Bạn đang có bao nhiêu?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        const SizedBox(height: 10),
        Text(
            'Nhập số dư hiện có để Tichi bắt đầu đúng. Có thể bỏ trống và sửa '
            'sau trong Thêm → Ví.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 15, height: 1.5, color: TichiColors.muted)),
        const SizedBox(height: 24),
        for (final wallet in wallets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: Key('opening-${wallet.name}'),
              controller: controllers.putIfAbsent(
                  wallet.id, () => TextEditingController()),
              keyboardType: TextInputType.numberWithOptions(
                  decimal: wallet.currencyCode == 'USD'),
              inputFormatters: moneyFormatters(wallet.currencyCode),
              decoration: InputDecoration(
                labelText: wallet.name,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconAvatar(
                      icon: wallet.icon, color: wallet.color, size: 32),
                ),
                suffixText: wallet.currencyCode == 'USD' ? 'USD' : '₫',
              ),
            ),
          ),
        const SizedBox(height: 4),
        Card(
          child: SwitchListTile(
            value: remind,
            onChanged: onRemind,
            title: const Text('Nhắc tôi tiết kiệm mỗi ngày'),
            subtitle: const Text('Lúc 20:00, đổi giờ được trong Thêm'),
          ),
        ),
        if (error != null) FormError(error!),
      ],
    );
  }
}

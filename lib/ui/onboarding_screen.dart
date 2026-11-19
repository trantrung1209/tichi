/// Hướng dẫn lần đầu dùng app: 3 trang giới thiệu và 1 trang nhập số dư hiện
/// có. Xem lại được từ mục Thêm.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/finance_core.dart';
import '../core/finance/money.dart';
import 'backup_screen.dart';
import 'brand.dart';
import 'icons.dart';
import 'widgets.dart';
import '../core/l10n.dart';

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
  bool _remindExpense = true;
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

  /// Đổi máy hoặc cài lại app: khôi phục bản sao lưu rồi vào thẳng Trang chủ.
  Future<void> _restore() async {
    final store = StoreScope.read(context);
    final restored = await restoreFromBackupFile(context);
    if (restored) store.completeOnboarding();
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
          setState(() => _error = tr('Số dư của ${wallet.name} không hợp lệ.', 'The balance of ${wallet.name} is not valid.'));
          return;
        }
        store.setOpeningBalance(wallet.id, amount);
      }
    } on FinanceException catch (error) {
      setState(() => _error = friendlyError(error));
      return;
    }
    if (_remind) await store.setReminder(enabled: true);
    if (_remindExpense) await store.setExpenseReminder(enabled: true);
    store.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isLast = _page == _pageCount - 1;
    final pages = <Widget>[
      _IntroPage(
        hero: TichiAppIcon(size: 96),
        title: tr('Chào mừng đến Tichi', 'Welcome to Tichi'),
        lead: tr('Tích từng chút, thành điều lớn.', 'Little by little, it adds up.'),
        points: [
          ('wallet', tr('Không cần tài khoản', 'No account needed'), tr('Mở app là dùng được ngay.', 'Open the app and start right away.')),
          ('internet', tr('Không cần Internet', 'No Internet needed'), tr('Mọi tính năng chạy ngay trên máy.', 'Everything runs on your phone.')),
          ('insurance', tr('Dữ liệu là của bạn', 'Your data is yours'),
              tr('Chỉ nằm trên điện thoại này. Không quảng cáo, không theo dõi.', 'It stays on this phone. No ads, no tracking.')),
        ],
      ),
      _IntroPage(
        hero: IconAvatar(icon: 'bills', color: 'blue', size: 96),
        title: tr('Ghi thu chi trong vài giây', 'Log income and expenses in seconds'),
        lead: tr('Bấm nút + ở Trang chủ, nhập số tiền, chọn danh mục và ví.', 'Tap + on Home, enter the amount, pick a category and a wallet.'),
        points: [
          ('transfer', tr('Chuyển giữa các ví', 'Move money between wallets'),
              tr('Rút tiền ATM hay nạp ví điện tử là chuyển ví, không tính là chi.', 'ATM withdrawals or e-wallet top-ups are transfers, not expenses.')),
          ('more', tr('Vuốt sang trái để xóa', 'Swipe left to delete'), tr('Lỡ tay thì bấm Hoàn tác.', 'Made a mistake? Tap Undo.')),
          ('budget', tr('Đặt ngân sách tháng', 'Set monthly budget'),
              tr('Tichi báo khi bạn đã dùng 80% và khi vượt mức.', 'Tichi lets you know at 80% and when you go over.')),
        ],
      ),
      _IntroPage(
        hero: IconAvatar(icon: 'savings', color: 'gold', size: 96),
        title: tr('Tiết kiệm bằng tiền thật', 'Save with real money'),
        lead: tr('Mỗi lần tiết kiệm là chuyển tiền thật vào ví tiết kiệm, '
            'không phải con số ảo.', 'Every saving is a real transfer into your savings wallet, ' 'not just a number.'),
        points: [
          ('travel', tr('Đặt mục tiêu', 'Set goals'), tr('Du lịch, điện thoại mới, quỹ dự phòng...', 'A trip, a new phone, an emergency fund...')),
          ('coins', tr('Biết mỗi ngày cần bao nhiêu', 'Know how much each day'),
              tr('Tichi tính số nên dành mỗi ngày để kịp hạn.', 'Tichi works out how much to set aside daily to reach your goal.')),
          ('bonus', tr('Giữ chuỗi ngày', 'Keep your streak'),
              tr('Bỏ một hôm cũng không sao, cứ tiếp tục là được.', 'Missed a day? No problem, just keep going.')),
        ],
      ),
      if (!widget.replay)
        _BalancePage(
          wallets: store.spendingWallets(),
          controllers: _balances,
          remind: _remind,
          onRemind: (value) => setState(() => _remind = value),
          remindExpense: _remindExpense,
          onRemindExpense: (value) => setState(() => _remindExpense = value),
          currency: store.baseCurrency,
          onCurrency: (currency) {
            // Số đã gõ theo loại tiền cũ không còn đúng nữa.
            for (final controller in _balances.values) {
              controller.clear();
            }
            store.useCurrency(currency);
          },
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
                  child: Text(isLast ? '' : tr('Bỏ qua', 'Skip')),
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
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, !widget.replay && _page == 0 ? 4 : 16),
              child: FilledButton(
                key: const Key('onboarding-next'),
                onPressed: _next,
                child: Text(isLast
                    ? (widget.replay ? tr('Đã hiểu', 'Got it') : tr('Bắt đầu dùng Tichi', 'Start using Tichi'))
                    : tr('Tiếp', 'Next')),
              ),
            ),
            if (!widget.replay && _page == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  key: const Key('onboarding-restore'),
                  onPressed: _restore,
                  icon: const Icon(Icons.restore, size: 20),
                  label: Text(tr('Đã có bản sao lưu? Khôi phục', 'Have a backup? Restore')),
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
    required this.remindExpense,
    required this.onRemindExpense,
    required this.currency,
    required this.onCurrency,
    required this.error,
  });

  final List<WalletInfo> wallets;
  final Map<String, TextEditingController> controllers;
  final bool remind;
  final ValueChanged<bool> onRemind;
  final bool remindExpense;
  final ValueChanged<bool> onRemindExpense;
  final String currency;
  final ValueChanged<String> onCurrency;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        const Center(
            child: IconAvatar(icon: 'cash', color: 'green', size: 96)),
        const SizedBox(height: 28),
        Text(tr('Bạn đang có bao nhiêu?', 'How much do you have now?'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        const SizedBox(height: 10),
        Text(
            tr('Nhập số dư hiện có để Tichi bắt đầu đúng. Có thể bỏ trống và sửa '
            'sau trong Thêm → Ví.', 'Enter your current balances so Tichi starts out right. You can leave ' 'them empty and edit later in More › Wallets.'),
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 15, height: 1.5, color: TichiColors.muted)),
        const SizedBox(height: 20),
        Text(tr('Bạn chủ yếu dùng loại tiền nào?', 'Which currency do you mostly use?'),
            style: TichiText.section),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            key: const Key('onboarding-currency'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'VND', label: Text('VND (₫)')),
              ButtonSegment(value: 'USD', label: Text('USD (\$)')),
            ],
            selected: {currency},
            onSelectionChanged: (s) => onCurrency(s.first),
          ),
        ),
        const SizedBox(height: 20),
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
            title: Text(tr('Nhắc tôi tiết kiệm', 'Remind me to save')),
            subtitle: Text(tr('Mỗi ngày lúc 20:00. Đổi sang mỗi tuần, mỗi tháng trong Thêm',
                'Daily at 8:00 PM. Switch to weekly or monthly in More')),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            key: const Key('onboarding-expense-reminder'),
            value: remindExpense,
            onChanged: onRemindExpense,
            title: Text(tr('Nhắc khi cả ngày chưa ghi chi tiêu',
                'Remind me if I log nothing all day')),
            subtitle: Text(tr('Lúc 20:00, chỉ khi hôm đó chưa ghi khoản chi nào',
                'At 8:00 PM, only on days with no expenses logged')),
          ),
        ),
        if (error != null) FormError(error!),
      ],
    );
  }
}

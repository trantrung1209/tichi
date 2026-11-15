/// Mục Thêm: ví, danh mục, nhắc tiết kiệm, sao lưu, loại tiền và tỷ giá.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/strings.dart';
import '../app/theme.dart';
import '../core/finance/money.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'brand.dart';
import 'categories_screen.dart';
import 'icons.dart';
import 'name_screen.dart';
import 'onboarding_screen.dart';
import 'wallet_form_screen.dart';
import 'widgets.dart';
import '../core/l10n.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _toggleReminder(BuildContext context, bool enabled) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await store.setReminder(enabled: enabled);
    if (!ok) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr('Tichi chưa được phép hiện thông báo. Bật quyền thông '
              'báo cho Tichi trong Cài đặt của điện thoại.', 'Tichi isn\'t allowed to show notifications. Turn on ' 'notifications for Tichi in your phone\'s Settings.'))));
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final store = StoreScope.read(context);
    final (hour, minute) = store.reminderTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null) return;
    await store.setReminder(
        enabled: true, hour: picked.hour, minute: picked.minute);
  }

  /// Đổi loại tiền hiển thị. Nếu còn ví chưa dùng ở loại tiền khác (ví dụ
  /// ví mặc định tạo theo ngôn ngữ máy), hỏi có đổi luôn các ví đó không.
  Future<void> _changeBaseCurrency(BuildContext context, String currency) async {
    final store = StoreScope.read(context);
    final candidates = store.walletsConvertibleTo(currency);
    if (candidates.isEmpty) {
      store.setBaseCurrency(currency);
      return;
    }
    final names = candidates.map((w) => w.name).join(', ');
    final convert = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Đổi luôn các ví sang $currency?',
            'Switch your wallets to $currency too?')),
        content: Text(tr(
            'Các ví chưa có giao dịch nào: $names. Đổi sang $currency để ghi '
                'giao dịch bằng $currency.',
            'These wallets have no transactions yet: $names. Switch them to '
                '$currency so you can record transactions in $currency.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Chỉ đổi cách hiển thị', 'Display only')),
          ),
          TextButton(
            key: const Key('convert-wallets'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Đổi luôn', 'Switch them')),
          ),
        ],
      ),
    );
    if (convert == null) return;
    if (convert) {
      store.useCurrency(currency);
    } else {
      store.setBaseCurrency(currency);
    }
  }

  Future<void> _toggleExpenseReminder(BuildContext context, bool enabled) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await store.setExpenseReminder(enabled: enabled);
    if (!ok) {
      messenger.showSnackBar(SnackBar(
          content: Text(tr(
              'Tichi chưa được phép hiện thông báo. Bật quyền thông báo cho '
                  'Tichi trong Cài đặt của điện thoại.',
              'Tichi isn\'t allowed to show notifications. Turn on '
                  'notifications for Tichi in your phone\'s Settings.'))));
    }
  }

  Future<void> _pickExpenseTime(BuildContext context) async {
    final store = StoreScope.read(context);
    final (hour, minute) = store.expenseReminderTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null) return;
    await store.setExpenseReminder(
        enabled: true, hour: picked.hour, minute: picked.minute);
  }

  Future<void> _pickWeekday(BuildContext context) async {
    final store = StoreScope.read(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var day = 1; day <= 7; day++)
              ListTile(
                title: Text(weekdayName(day)),
                trailing: day == store.reminderWeekday
                    ? Icon(Icons.check, color: TichiColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, day),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await store.setReminder(enabled: true, weekday: picked);
  }

  Future<void> _pickMonthDay(BuildContext context) async {
    final store = StoreScope.read(context);
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Nhắc vào ngày', 'Remind on day')),
        content: SizedBox(
          width: 320,
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var day = 1; day <= 28; day++)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(dialogContext, day),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: day == store.reminderMonthDay
                          ? TichiColors.primary
                          : null,
                    ),
                    child: Text('$day',
                        style: TextStyle(
                            color: day == store.reminderMonthDay
                                ? Theme.of(dialogContext).colorScheme.onPrimary
                                : TichiColors.ink)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
                tr('Chỉ đến ngày 28 để tháng nào cũng có.',
                    'Up to day 28 so every month has it.'),
                style: TichiText.label),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await store.setReminder(enabled: true, monthDay: picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rate = store.usdVndRate;
    final walletCount = store.allWallets().length;
    final (hour, minute) = store.reminderTime;
    final timeText =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    final (expenseHour, expenseMinute) = store.expenseReminderTime;
    final expenseTimeText =
        '${expenseHour.toString().padLeft(2, '0')}:${expenseMinute.toString().padLeft(2, '0')}';
    final scheduleText = switch (store.reminderFrequency) {
      'weekly' => tr('${weekdayName(store.reminderWeekday)}, lúc $timeText',
          '${weekdayName(store.reminderWeekday)} at $timeText'),
      'monthly' => tr(
          'Ngày ${store.reminderMonthDay} hằng tháng, lúc $timeText',
          'Day ${store.reminderMonthDay} of each month at $timeText'),
      _ => tr('Mỗi ngày lúc $timeText, theo mục tiêu ưu tiên',
          'Every day at $timeText, for your top-priority goal'),
    };
    final lastBackup = store.core.getSetting('last_backup_at');

    void open(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    Widget item({
      required String icon,
      required String color,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
      Widget? trailing,
    }) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconAvatar(icon: icon, color: color),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: trailing ??
              (onTap == null ? null : const Icon(Icons.chevron_right)),
          enabled: onTap != null || trailing != null,
          onTap: onTap,
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(tr('Thêm', 'More'), style: TichiText.pageTitle),
          const SizedBox(height: 16),
          _ProfileCard(
            name: store.userName,
            onEdit: () => showEditNameDialog(context),
          ),
          const SizedBox(height: 16),
          GroupCard(children: [
            item(
              icon: 'wallet',
              color: 'emerald',
              title: tr('Ví', 'Wallet'),
              subtitle: tr('$walletCount ví đang dùng', '$walletCount wallets in use'),
              onTap: () => open(const WalletsScreen()),
            ),
            item(
              icon: 'shopping',
              color: 'pink',
              title: tr('Danh mục', 'Category'),
              subtitle: tr('Biểu tượng, màu, ẩn hoặc thêm danh mục', 'Icons, colors, hide or add categories'),
              onTap: () => open(const CategoriesScreen()),
            ),
          ]),
          const SizedBox(height: 16),
          FieldLabel(tr('Nhắc tiết kiệm', 'Savings reminder')),
          GroupCard(children: [
            item(
              icon: 'bills',
              color: 'gold',
              title: tr('Nhắc gửi tiết kiệm', 'Savings reminder'),
              subtitle: store.reminderEnabled
                  ? scheduleText
                  : tr('Đang tắt', 'Off'),
              trailing: Switch(
                key: const Key('reminder-switch'),
                value: store.reminderEnabled,
                onChanged: (value) => _toggleReminder(context, value),
              ),
            ),
            if (store.reminderEnabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    key: const Key('reminder-frequency'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                          value: 'daily',
                          label: Text(tr('Mỗi ngày', 'Daily'))),
                      ButtonSegment(
                          value: 'weekly',
                          label: Text(tr('Mỗi tuần', 'Weekly'))),
                      ButtonSegment(
                          value: 'monthly',
                          label: Text(tr('Mỗi tháng', 'Monthly'))),
                    ],
                    selected: {store.reminderFrequency},
                    onSelectionChanged: (s) => StoreScope.read(context)
                        .setReminder(enabled: true, frequency: s.first),
                  ),
                ),
              ),
              if (store.reminderFrequency == 'weekly')
                item(
                  icon: 'more',
                  color: 'stone',
                  title: tr('Nhắc vào', 'Remind on'),
                  subtitle: weekdayName(store.reminderWeekday),
                  onTap: () => _pickWeekday(context),
                ),
              if (store.reminderFrequency == 'monthly')
                item(
                  icon: 'more',
                  color: 'stone',
                  title: tr('Nhắc vào ngày', 'Remind on day'),
                  subtitle: tr('Ngày ${store.reminderMonthDay} hằng tháng',
                      'Day ${store.reminderMonthDay} of every month'),
                  onTap: () => _pickMonthDay(context),
                ),
              item(
                icon: 'more',
                color: 'stone',
                title: tr('Giờ nhắc', 'Reminder time'),
                subtitle: timeText,
                onTap: () => _pickReminderTime(context),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          FieldLabel(tr('Nhắc ghi chi tiêu', 'Expense reminder')),
          GroupCard(children: [
            item(
              icon: 'shopping',
              color: 'pink',
              title: tr('Nhắc khi cả ngày chưa ghi', 'Remind if nothing logged'),
              subtitle: store.expenseReminderEnabled
                  ? tr('Lúc $expenseTimeText, chỉ khi hôm đó chưa ghi khoản nào',
                      'At $expenseTimeText, only on days with nothing logged')
                  : tr('Đang tắt', 'Off'),
              trailing: Switch(
                key: const Key('expense-reminder-switch'),
                value: store.expenseReminderEnabled,
                onChanged: (value) => _toggleExpenseReminder(context, value),
              ),
            ),
            if (store.expenseReminderEnabled)
              item(
                icon: 'more',
                color: 'stone',
                title: tr('Giờ nhắc', 'Reminder time'),
                subtitle: expenseTimeText,
                onTap: () => _pickExpenseTime(context),
              ),
          ]),
          const SizedBox(height: 16),
          FieldLabel(tr('Giao diện', 'Appearance')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  key: const Key('theme-mode'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: 'system',
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text(tr('Theo máy', 'System'))),
                    ButtonSegment(
                        value: 'light',
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text(tr('Sáng', 'Light'))),
                    ButtonSegment(
                        value: 'dark',
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text(tr('Tối', 'Dark'))),
                  ],
                  selected: {store.themeMode},
                  onSelectionChanged: (s) =>
                      StoreScope.read(context).setThemeMode(s.first),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel(TichiStrings.languageTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  key: const Key('language'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: 'system', label: Text(tr('Theo máy', 'System'))),
                    const ButtonSegment(value: 'vi', label: Text('Tiếng Việt')),
                    const ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {store.language},
                  onSelectionChanged: (s) =>
                      StoreScope.read(context).setLanguage(s.first),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel(tr('Dữ liệu', 'Data')),
          GroupCard(children: [
            item(
              icon: 'insurance',
              color: 'green',
              title: tr('Sao lưu và khôi phục', 'Backup & restore'),
              subtitle: lastBackup == null
                  ? tr('Chưa sao lưu lần nào', 'No backup yet')
                  : tr('Gần nhất ${shortDate(lastBackup)}', 'Last ${shortDate(lastBackup)}'),
              onTap: () => open(const BackupScreen()),
            ),
          ]),
          const SizedBox(height: 16),
          FieldLabel(tr('Loại tiền hiển thị', 'Display currency')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'VND', label: Text('VND')),
                      ButtonSegment(value: 'USD', label: Text('USD')),
                    ],
                    selected: {store.baseCurrency},
                    onSelectionChanged: (s) =>
                        _changeBaseCurrency(context, s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      tr('Trang chủ, Tiết kiệm và Ngân sách quy mọi số tiền về '
                      'loại tiền này.', 'Home, Savings and Budgets convert all amounts to ' 'this currency.'),
                      style: TichiText.label),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GroupCard(children: [
            item(
              icon: 'invest',
              color: 'blue',
              title: tr('Tỷ giá USD', 'USD exchange rate'),
              subtitle: rate == null
                  ? tr('Chưa nhập', 'Not set')
                  : '1 USD = ${formatMinor(rate, 'VND')}',
              onTap: () => showRateDialog(context),
            ),
          ]),
          const SizedBox(height: 16),
          FieldLabel(tr('Về Tichi', 'About Tichi')),
          GroupCard(children: [
            item(
              icon: 'guide',
              color: 'blue',
              title: TichiStrings.guideMenu,
              subtitle: TichiStrings.guideMenuSubtitle,
              onTap: () => open(const OnboardingScreen(replay: true)),
            ),
            item(
              icon: 'info',
              color: 'emerald',
              title: TichiStrings.aboutMenu,
              subtitle: TichiStrings.aboutMenuSubtitle,
              onTap: () => open(const AboutScreen()),
            ),
          ]),
          const SizedBox(height: 24),
          const Center(child: TichiAppIcon(size: 48)),
          const SizedBox(height: 8),
          Text(TichiStrings.aboutCredit(),
              textAlign: TextAlign.center, style: TichiText.label),
          const SizedBox(height: 2),
          Text(tr('Dữ liệu chỉ nằm trên máy này', 'Your data stays on this phone'),
              textAlign: TextAlign.center, style: TichiText.label),
        ],
      ),
    );
  }
}

/// Hồ sơ: chữ cái đầu, tên gọi và nút sửa tên.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.onEdit});

  final String? name;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final display = name ?? tr('Bạn', 'You');
    final initial = display.characters.first.toUpperCase();
    return Card(
      key: const Key('profile-card'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TichiColors.brand,
                  shape: BoxShape.circle,
                ),
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: TichiColors.ink)),
                    const SizedBox(height: 2),
                    Text(tr('Tên gọi Tichi dùng để chào bạn', 'The name Tichi uses to greet you'),
                        style: TichiText.caption),
                  ],
                ),
              ),
              IconButton(
                key: const Key('edit-name'),
                tooltip: tr('Sửa tên gọi', 'Edit name'),
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: TichiColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tên thứ trong tuần: 1 = thứ Hai … 7 = Chủ nhật.
String weekdayName(int day) => switch (day) {
      1 => tr('Thứ Hai', 'Monday'),
      2 => tr('Thứ Ba', 'Tuesday'),
      3 => tr('Thứ Tư', 'Wednesday'),
      4 => tr('Thứ Năm', 'Thursday'),
      5 => tr('Thứ Sáu', 'Friday'),
      6 => tr('Thứ Bảy', 'Saturday'),
      _ => tr('Chủ nhật', 'Sunday'),
    };

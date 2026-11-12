/// Mục Thêm: ví, danh mục, nhắc tiết kiệm, sao lưu, loại tiền và tỷ giá.
library;

import 'package:flutter/material.dart';

import '../app/store.dart';
import '../app/theme.dart';
import '../core/finance/money.dart';
import 'backup_screen.dart';
import 'brand.dart';
import 'categories_screen.dart';
import 'icons.dart';
import 'onboarding_screen.dart';
import 'wallet_form_screen.dart';
import 'widgets.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _toggleReminder(BuildContext context, bool enabled) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await store.setReminder(enabled: enabled);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Tichi chưa được phép hiện thông báo. Bật quyền thông '
              'báo cho Tichi trong Cài đặt của điện thoại.')));
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rate = store.usdVndRate;
    final walletCount = store.allWallets().length;
    final (hour, minute) = store.reminderTime;
    final timeText =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
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
          Text('Thêm', style: TichiText.pageTitle),
          const SizedBox(height: 16),
          GroupCard(children: [
            item(
              icon: 'wallet',
              color: 'emerald',
              title: 'Ví',
              subtitle: '$walletCount ví đang dùng',
              onTap: () => open(const WalletsScreen()),
            ),
            item(
              icon: 'shopping',
              color: 'pink',
              title: 'Danh mục',
              subtitle: 'Biểu tượng, màu, ẩn hoặc thêm danh mục',
              onTap: () => open(const CategoriesScreen()),
            ),
          ]),
          const SizedBox(height: 16),
          const FieldLabel('Nhắc tiết kiệm'),
          GroupCard(children: [
            item(
              icon: 'bills',
              color: 'gold',
              title: 'Nhắc mỗi ngày',
              subtitle: store.reminderEnabled
                  ? 'Lúc $timeText, theo mục tiêu ưu tiên'
                  : 'Đang tắt',
              trailing: Switch(
                key: const Key('reminder-switch'),
                value: store.reminderEnabled,
                onChanged: (value) => _toggleReminder(context, value),
              ),
            ),
            if (store.reminderEnabled)
              item(
                icon: 'more',
                color: 'stone',
                title: 'Giờ nhắc',
                subtitle: timeText,
                onTap: () => _pickReminderTime(context),
              ),
          ]),
          const SizedBox(height: 16),
          const FieldLabel('Giao diện'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  key: const Key('theme-mode'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: 'system',
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('Theo máy')),
                    ButtonSegment(
                        value: 'light',
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Sáng')),
                    ButtonSegment(
                        value: 'dark',
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Tối')),
                  ],
                  selected: {store.themeMode},
                  onSelectionChanged: (s) =>
                      StoreScope.read(context).setThemeMode(s.first),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Dữ liệu'),
          GroupCard(children: [
            item(
              icon: 'insurance',
              color: 'green',
              title: 'Sao lưu và khôi phục',
              subtitle: lastBackup == null
                  ? 'Chưa sao lưu lần nào'
                  : 'Gần nhất ${shortDate(lastBackup)}',
              onTap: () => open(const BackupScreen()),
            ),
          ]),
          const SizedBox(height: 16),
          const FieldLabel('Loại tiền hiển thị'),
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
                        StoreScope.read(context).setBaseCurrency(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Trang chủ, Tiết kiệm và Ngân sách quy mọi số tiền về '
                      'loại tiền này.',
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
              title: 'Tỷ giá USD',
              subtitle: rate == null
                  ? 'Chưa nhập'
                  : '1 USD = ${formatMinor(rate, 'VND')}',
              onTap: () => showRateDialog(context),
            ),
          ]),
          const SizedBox(height: 16),
          GroupCard(children: [
            item(
              icon: 'more',
              color: 'stone',
              title: 'Xem lại hướng dẫn',
              onTap: () => open(const OnboardingScreen(replay: true)),
            ),
            item(
              icon: 'insurance',
              color: 'stone',
              title: 'Khóa bằng mã PIN, vân tay',
              subtitle: 'Sắp có',
            ),
          ]),
          const SizedBox(height: 24),
          const Center(child: TichiAppIcon(size: 48)),
          const SizedBox(height: 8),
          Text('Tichi 1.0 · Dữ liệu chỉ nằm trên máy này',
              textAlign: TextAlign.center, style: TichiText.label),
        ],
      ),
    );
  }
}

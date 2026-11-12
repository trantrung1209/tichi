/// Bộ biểu tượng và bảng màu của Tichi. Cơ sở dữ liệu chỉ lưu tên (khóa);
/// tên đổi ra biểu tượng và màu ở đây.
library;

import 'package:flutter/material.dart';

import '../app/theme.dart';

const Map<String, IconData> tichiIcons = {
  'food': Icons.restaurant,
  'coffee': Icons.local_cafe,
  'transport': Icons.two_wheeler,
  'car': Icons.directions_car,
  'fuel': Icons.local_gas_station,
  'shopping': Icons.shopping_bag,
  'home': Icons.home,
  'bills': Icons.receipt_long,
  'electricity': Icons.bolt,
  'water': Icons.water_drop,
  'internet': Icons.wifi,
  'phone': Icons.smartphone,
  'health': Icons.medical_services,
  'education': Icons.school,
  'entertainment': Icons.movie,
  'travel': Icons.flight,
  'gift': Icons.card_giftcard,
  'family': Icons.family_restroom,
  'pet': Icons.pets,
  'beauty': Icons.spa,
  'sport': Icons.fitness_center,
  'insurance': Icons.health_and_safety,
  'subscription': Icons.subscriptions,
  'laptop': Icons.laptop,
  'salary': Icons.payments,
  'bonus': Icons.emoji_events,
  'business': Icons.storefront,
  'invest': Icons.trending_up,
  'cash': Icons.account_balance_wallet,
  'bank': Icons.account_balance,
  'card': Icons.credit_card,
  'wallet': Icons.wallet,
  'coins': Icons.toll,
  'savings': Icons.savings,
  'budget': Icons.pie_chart,
  'transfer': Icons.swap_horiz,
  'more': Icons.more_horiz,
};

/// Biểu tượng gợi ý cho từng nơi chọn.
const List<String> categoryIconChoices = [
  'food', 'coffee', 'transport', 'car', 'fuel', 'shopping', 'home', 'bills',
  'electricity', 'water', 'internet', 'phone', 'health', 'education',
  'entertainment', 'travel', 'gift', 'family', 'pet', 'beauty', 'sport',
  'insurance', 'subscription', 'laptop', 'salary', 'bonus', 'business',
  'invest', 'more',
];

const List<String> walletIconChoices = [
  'cash', 'bank', 'card', 'phone', 'wallet', 'coins', 'savings', 'business',
];

const List<String> goalIconChoices = [
  'savings', 'travel', 'home', 'car', 'transport', 'phone', 'laptop',
  'education', 'health', 'family', 'gift', 'pet',
];

/// Màu nền nhạt và màu biểu tượng đậm cùng tông.
class TichiTint {
  const TichiTint(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

const Map<String, TichiTint> tichiTints = {
  'emerald': TichiTint(Color(0xFFE3EDE7), Color(0xFF0B4F3F)),
  'green': TichiTint(Color(0xFFE5F0E1), Color(0xFF2F6B2A)),
  'teal': TichiTint(Color(0xFFDFF0EE), Color(0xFF1D6660)),
  'blue': TichiTint(Color(0xFFE2ECF5), Color(0xFF1F5584)),
  'purple': TichiTint(Color(0xFFECE6F4), Color(0xFF5B3F8C)),
  'pink': TichiTint(Color(0xFFF6E3EC), Color(0xFF8E2F5E)),
  'red': TichiTint(Color(0xFFF6E4E1), Color(0xFF8C2F1B)),
  'orange': TichiTint(Color(0xFFF8E9DC), Color(0xFF9A4A12)),
  'gold': TichiTint(Color(0xFFF5EDD9), Color(0xFF7A5A12)),
  'stone': TichiTint(Color(0xFFECE8DF), Color(0xFF4A4F4C)),
};

IconData iconFor(String? key) => tichiIcons[key] ?? Icons.more_horiz;

/// Màu theo [key]. Ở giao diện tối, nền là màu đậm pha tối và biểu tượng
/// sáng lên để vẫn dễ nhìn.
TichiTint tintFor(String? key) {
  final light = tichiTints[key] ?? tichiTints['stone']!;
  if (!TichiColors.dark) return light;
  final fg = light.foreground;
  return TichiTint(
    Color.alphaBlend(fg.withValues(alpha: 0.42), TichiColors.surface),
    Color.lerp(fg, Colors.white, 0.62)!,
  );
}

/// Biểu tượng tròn có nền màu nhạt.
class IconAvatar extends StatelessWidget {
  const IconAvatar({super.key, this.icon, this.color, this.size = 36});

  final String? icon;
  final String? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = tintFor(color);
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: tint.background, shape: BoxShape.circle),
      child: Icon(iconFor(icon), size: size * 0.5, color: tint.foreground),
    );
  }
}

/// Chọn biểu tượng và màu. [colorKey] null thì ẩn phần chọn màu.
class IconColorPicker extends StatelessWidget {
  const IconColorPicker({
    super.key,
    required this.icons,
    required this.iconKey,
    required this.onIcon,
    this.colorKey,
    this.onColor,
  });

  final List<String> icons;
  final String iconKey;
  final ValueChanged<String> onIcon;
  final String? colorKey;
  final ValueChanged<String>? onColor;

  @override
  Widget build(BuildContext context) {
    final tint = tintFor(colorKey ?? 'emerald');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in icons)
              Semantics(
                button: true,
                selected: key == iconKey,
                label: 'Biểu tượng $key',
                child: InkResponse(
                  onTap: () => onIcon(key),
                  radius: 26,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: key == iconKey ? tint.background : TichiColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: key == iconKey
                            ? tint.foreground
                            : TichiColors.line,
                        width: key == iconKey ? 2 : 1,
                      ),
                    ),
                    child: Icon(iconFor(key),
                        size: 22,
                        color: key == iconKey
                            ? tint.foreground
                            : TichiColors.muted),
                  ),
                ),
              ),
          ],
        ),
        if (colorKey != null && onColor != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in tichiTints.entries)
                Semantics(
                  button: true,
                  selected: entry.key == colorKey,
                  label: 'Màu ${entry.key}',
                  child: InkResponse(
                    onTap: () => onColor!(entry.key),
                    radius: 24,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tintFor(entry.key).background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: entry.key == colorKey
                              ? tintFor(entry.key).foreground
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                              color: tintFor(entry.key).foreground,
                              shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

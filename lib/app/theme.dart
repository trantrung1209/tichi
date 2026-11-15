/// Giao diện sáng và tối của Tichi, theo bản vẽ "Tichi – Thiết kế màn hình".
library;

import 'package:flutter/material.dart';

/// Bảng màu đang dùng. [dark] do TichiApp đặt mỗi khi đổi giao diện; mọi màn
/// hình đọc màu qua các getter bên dưới nên tự đổi theo khi vẽ lại.
class TichiColors {
  static bool dark = false;

  static Color _pick(int light, int night) => Color(dark ? night : light);

  /// Nền màn hình.
  static Color get background => _pick(0xFFF6F4EF, 0xFF111413);

  /// Nền thẻ, ô nhập.
  static Color get surface => _pick(0xFFFFFFFF, 0xFF1B1F1D);

  /// Chữ chính.
  static Color get ink => _pick(0xFF1F2422, 0xFFE9ECE9);

  /// Chữ phụ.
  static Color get muted => _pick(0xFF5F6360, 0xFFA2A8A4);

  /// Đường kẻ, viền.
  static Color get line => _pick(0xFFE4E0D8, 0xFF2D3330);

  /// Nền thanh tiến độ.
  static Color get track => _pick(0xFFECE8DF, 0xFF2A302D);

  /// Màu nhấn: chữ, biểu tượng, nút. Ở nền tối sáng hơn để dễ đọc.
  static Color get primary => _pick(0xFF0B4F3F, 0xFF5CC79E);

  /// Nền các khối lớn chữ trắng (thẻ Tổng tài sản, Tổng tiết kiệm).
  static Color get brand => _pick(0xFF0B4F3F, 0xFF135C4A);

  /// Nền nhạt cùng tông màu nhấn.
  static Color get primarySoft => _pick(0xFFE3EDE7, 0xFF1C3A31);

  /// Chữ phụ trên nền [primarySoft].
  static Color get softText => _pick(0xFF2F5A4C, 0xFFA9D3C2);

  /// Chữ nhạt trên nền [brand].
  static Color get onPrimaryMuted => _pick(0xFFCFE3DA, 0xFFBFDCCF);

  static Color get warning => _pick(0xFFB26A00, 0xFFE3A23A);
  static Color get warningText => _pick(0xFF7A4A00, 0xFFF1C677);

  /// Nền nhạt của thông báo cảnh báo.
  static Color get warningSoft => _pick(0xFFFFF4E0, 0xFF3A2C14);

  static Color get danger => _pick(0xFF8C2F1B, 0xFFEE8B73);

  /// Màu màn hình chờ, luôn giống màn hình chờ của Android.
  static const splash = Color(0xFF0B4F3F);
}

/// Dựng bộ giao diện cho nền sáng hoặc tối.
ThemeData buildTheme([Brightness brightness = Brightness.light]) {
  final previous = TichiColors.dark;
  TichiColors.dark = brightness == Brightness.dark;
  try {
    return _build(brightness);
  } finally {
    TichiColors.dark = previous;
  }
}

ThemeData _build(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B4F3F),
    brightness: brightness,
    primary: TichiColors.primary,
    onPrimary: dark ? const Color(0xFF07261E) : Colors.white,
    surface: TichiColors.background,
    onSurface: TichiColors.ink,
    onSurfaceVariant: TichiColors.muted,
    outline: TichiColors.line,
    error: TichiColors.danger,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'BeVietnamPro',
    colorScheme: scheme,
    scaffoldBackgroundColor: TichiColors.background,
    canvasColor: TichiColors.background,
    // Chuyển màn hình: màn mới trượt vào và hiện dần, màn cũ lùi nhẹ.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: TichiColors.background,
      foregroundColor: TichiColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: TichiColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(backgroundColor: TichiColors.surface),
    bottomSheetTheme:
        BottomSheetThemeData(backgroundColor: TichiColors.surface),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: shape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: TichiColors.brand,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TichiColors.surface,
      indicatorColor: TichiColors.primarySoft,
    ),
    dividerTheme: DividerThemeData(color: TichiColors.line, space: 1),
  );
}

/// Kiểu chữ dùng nhiều lần. Là getter để đổi màu theo giao diện sáng/tối.
class TichiText {
  static TextStyle get pageTitle => TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: TichiColors.ink);
  static TextStyle get section => TextStyle(
      fontSize: 15, fontWeight: FontWeight.w600, color: TichiColors.ink);
  static TextStyle get label =>
      TextStyle(fontSize: 12, color: TichiColors.muted);
  static TextStyle get caption =>
      TextStyle(fontSize: 13, color: TichiColors.muted);
  static TextStyle get amount => TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: TichiColors.ink,
      fontFeatures: const [FontFeature.tabularFigures()]);
}

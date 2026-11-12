/// Màn hình chuyển khi mở app: nền xanh, logo, tên app và câu khẩu hiệu.
/// Hiện trong lúc mở cơ sở dữ liệu, tối thiểu khoảng 1,4 giây.
library;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'brand.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoIn = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack));
    final textIn = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1, curve: Curves.easeOut));
    // Luôn là màu xanh thương hiệu, trùng màn hình chờ của Android.
    return ColoredBox(
      color: TichiColors.splash,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1).animate(logoIn),
              child: FadeTransition(
                opacity: logoIn,
                child: const TichiLogoMark(size: 120),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: textIn,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.3), end: Offset.zero)
                    .animate(textIn),
                child: Column(
                  children: [
                    Text('tichi',
                        style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.5,
                            color: Colors.white,
                            decoration: TextDecoration.none)),
                    SizedBox(height: 6),
                    Text('Tích từng chút, thành điều lớn.',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: TichiColors.onPrimaryMuted,
                            decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

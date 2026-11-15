/// Giới thiệu về Tichi: Tichi là gì, giúp gì, có những tính năng nào. Đọc
/// trong khoảng nửa phút.
library;

import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../app/theme.dart';
import 'brand.dart';
import 'icons.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            const _FadeIn(
              delay: 0,
              child: Center(child: TichiAppIcon(size: 88)),
            ),
            const SizedBox(height: 16),
            _FadeIn(
              delay: 60,
              child: Text(TichiStrings.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: TichiColors.ink)),
            ),
            const SizedBox(height: 10),
            _FadeIn(
              delay: 120,
              child: Text(TichiStrings.aboutLead,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, height: 1.55, color: TichiColors.muted)),
            ),
            const SizedBox(height: 28),
            _FadeIn(
              delay: 180,
              child: Text(TichiStrings.aboutFeaturesTitle,
                  style: TichiText.section),
            ),
            const SizedBox(height: 10),
            _FadeIn(
              delay: 220,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (final (i, (icon, color, title, detail))
                          in TichiStrings.aboutFeatures.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconAvatar(icon: icon, color: color, size: 40),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: TichiColors.ink)),
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
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _FadeIn(
              delay: 280,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TichiColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: TichiColors.softText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(TichiStrings.aboutPrivacy,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: TichiColors.softText)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _FadeIn(
              delay: 340,
              child: Text(TichiStrings.aboutClosing,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: TichiColors.primary)),
            ),
            const SizedBox(height: 20),
            Text(TichiStrings.aboutCredit(),
                textAlign: TextAlign.center, style: TichiText.label),
          ],
        ),
      ),
    );
  }
}

/// Hiện dần và trượt nhẹ lên, lần lượt theo [delay] (mili giây).
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.delay, required this.child});

  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Logo Tichi vẽ bằng code (chữ t ghép từ đồng xu), nét sắc ở mọi cỡ.
library;

import 'package:flutter/material.dart';

import '../app/theme.dart';

const Color tichiCream = Color(0xFFF6F4EF);
const Color tichiGold = Color(0xFFD6A84F);

/// Chỉ phần hình chữ t, không có nền. [size] là cạnh của khung vuông.
class TichiLogoMark extends StatelessWidget {
  const TichiLogoMark({
    super.key,
    this.size = 96,
    this.coinColor = tichiCream,
    this.barColor = tichiGold,
  });

  final double size;
  final Color coinColor;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo Tichi',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(coinColor, barColor),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.coin, this.bar);

  final Color coin;
  final Color bar;

  @override
  void paint(Canvas canvas, Size size) {
    // Toạ độ theo khung 100 × 100, giống file logo SVG.
    final s = size.width / 100;
    void pill(double x, double y, double w, double h, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x * s, y * s, w * s, h * s), Radius.circular(h * s / 2)),
        Paint()..color = color,
      );
    }

    pill(41, 14, 18, 11, coin);
    pill(24, 30, 52, 12, bar);
    pill(41, 47, 18, 11, coin);
    pill(41, 63, 18, 11, coin);
    pill(41, 79, 31, 11, coin);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.coin != coin || old.bar != bar;
}

/// Biểu tượng app đầy đủ: nền xanh bo góc và chữ t.
class TichiAppIcon extends StatelessWidget {
  const TichiAppIcon({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TichiColors.brand,
        borderRadius: BorderRadius.circular(size * 0.23),
      ),
      child: TichiLogoMark(size: size),
    );
  }
}

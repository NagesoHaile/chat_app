import 'dart:math';

import 'package:flutter/material.dart';

/// Draws a colorful "photo" from a seed. No bitmaps, so memory stays tiny.
class FakeImagePainter extends CustomPainter {
  FakeImagePainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    final hue = r.nextDouble() * 360;
    final rect = Offset.zero & size;

    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          HSVColor.fromAHSV(1, hue, 0.5, 0.9).toColor(),
          HSVColor.fromAHSV(1, (hue + 60) % 360, 0.6, 0.6).toColor(),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final shape = Paint()..color = const Color(0x3CFFFFFF);
    for (var i = 0; i < 6; i++) {
      final c = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      canvas.drawCircle(c, 20 + r.nextDouble() * 60, shape);
    }
  }

  @override
  bool shouldRepaint(FakeImagePainter old) => old.seed != seed;
}

import 'package:flutter/material.dart';

const double kBubbleBig = 16;
const double kBubbleSmall = 5;

/// Telegram-style corners:
/// - the side facing the sender's other bubbles is tight (5) when grouped
/// - the last bubble of a group has a square corner where the tail attaches
BorderRadius bubbleRadius({
  required bool isMine,
  required bool isFirst,
  required bool isLast,
}) {
  const big = Radius.circular(kBubbleBig);
  final join = Radius.circular(isFirst ? kBubbleBig : kBubbleSmall);
  final tailCorner = Radius.circular(isLast ? 0 : kBubbleSmall);

  return isMine
      ? BorderRadius.only(
          topLeft: big, topRight: join, bottomLeft: big, bottomRight: tailCorner)
      : BorderRadius.only(
          topLeft: join, topRight: big, bottomLeft: tailCorner, bottomRight: big);
}

/// Paints the bubble background and (optionally) the little tail that sticks
/// out ~6px below/outside the bottom corner.
class BubblePainter extends CustomPainter {
  const BubblePainter({
    required this.color,
    required this.radius,
    required this.isMine,
    required this.hasTail,
  });

  final Color color;
  final BorderRadius radius;
  final bool isMine;
  final bool hasTail;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRRect(radius.toRRect(Offset.zero & size), paint);

    if (!hasTail) return;
    final w = size.width;
    final h = size.height;
    // Mirror x for outgoing bubbles (tail on the right).
    double x(double v) => isMine ? w - v : v;

    final tail = Path()
      ..moveTo(x(0), h - 9)
      ..cubicTo(x(0), h - 2, x(-1.5), h - 0.5, x(-6), h)
      ..lineTo(x(4), h)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(BubblePainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.isMine != isMine ||
      old.hasTail != hasTail;
}

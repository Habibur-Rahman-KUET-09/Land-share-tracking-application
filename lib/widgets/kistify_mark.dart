import 'package:flutter/material.dart';

/// Kistify's brand mark — three overlapping rings (gold/white/navy),
/// standing for multiple people coming together on one shared plan. Drawn
/// as vectors (matches assets/icon/icon_full.svg's proportions) so it stays
/// crisp from the app bar down to the smallest size, with no baked-in text.
class KistifyMark extends StatelessWidget {
  final double size;
  const KistifyMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _RingsPainter()));
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.225;
    final strokeWidth = size.width * 0.083;
    final spacing = size.width * 0.161;
    final centerY = size.height / 2;
    final centers = [
      Offset(size.width / 2 - spacing, centerY),
      Offset(size.width / 2, centerY),
      Offset(size.width / 2 + spacing, centerY),
    ];
    const colors = [Color(0xFFE3AE3F), Colors.white, Color(0xFF1B2A4A)];
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        centers[i],
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

/// Kistify's brand mark — a navy badge holding two interlocked rings (gold
/// + white), standing for two (or more) people sharing one plan. It paints
/// its own navy background so it reads correctly wherever it's placed —
/// the app icon, a teal gradient header, or a plain app bar — instead of
/// depending on the surrounding surface for contrast.
class KistifyMark extends StatelessWidget {
  final double size;
  const KistifyMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _MarkPainter()));
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.2246;
    final strokeWidth = size.width * 0.083;
    final spacing = size.width * 0.1465;
    final centerY = size.height / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.22)),
      Paint()..color = const Color(0xFF1B2A4A),
    );

    final centers = [
      Offset(size.width / 2 - spacing / 2, centerY),
      Offset(size.width / 2 + spacing / 2, centerY),
    ];
    const colors = [Color(0xFFE5B347), Colors.white];
    for (var i = 0; i < 2; i++) {
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

import 'package:flutter/material.dart';
import 'dart:math' as math;

class HeritagePattern extends StatelessWidget {
  final Color color;
  final double opacity;

  const HeritagePattern(
      {super.key, this.color = Colors.white, this.opacity = 0.06});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _EightPointStarPainter(color: color),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _EightPointStarPainter extends CustomPainter {
  final Color color;
  const _EightPointStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    const tile = 56.0;
    final cols = (size.width / tile).ceil() + 1;
    final rows = (size.height / tile).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final center = Offset(col * tile, row * tile);
        _drawEightPointStar(canvas, paint, center, tile * 0.42);
      }
    }
  }

  void _drawEightPointStar(
      Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path();
    const points = 8;
    for (var i = 0; i < points; i++) {
      final angle = (2 * math.pi / points) * i - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.42;
      final point = Offset(
          center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EightPointStarPainter oldDelegate) =>
      oldDelegate.color != color;
}

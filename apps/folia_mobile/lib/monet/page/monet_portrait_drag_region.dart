import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// Cached dashed portrait edit boundary, separate from pointer state.
class MonetPortraitDragRegion extends CustomPainter {
  MonetPortraitDragRegion(this.color);
  final Color color;
  final _path = Path(),
      _paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
  Size? _size;
  @override
  void paint(Canvas canvas, Size size) {
    if (_size != size) {
      _size = size;
      _path.reset();
      final outline = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(1),
            const Radius.circular(40),
          ),
        );
      for (final metric in outline.computeMetrics()) {
        for (double distance = 0; distance < metric.length; distance += 12) {
          _path.addPath(
            metric.extractPath(distance, math.min(distance + 6, metric.length)),
            Offset.zero,
          );
        }
      }
    }
    canvas.drawPath(_path, _paint..color = color);
  }

  @override
  bool shouldRepaint(MonetPortraitDragRegion old) => old.color != color;
}

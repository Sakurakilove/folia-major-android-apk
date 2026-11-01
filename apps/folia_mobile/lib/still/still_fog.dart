import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

// CSS ellipse farthest-corner gradient; daylight uses multiply against its existing surface, without an extra background.
class StillFog extends CustomPainter {
  StillFog({required this.daylight});
  final bool daylight;
  final _paint = Paint();
  Size? _size;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size) {
      _size = size;
      _paint.shader = ui.Gradient.radial(Offset.zero, 1, [
        const Color(0x00000000),
        Color.fromRGBO(0, 0, 0, daylight ? .3 : .65),
      ]);
      _paint.blendMode = daylight ? BlendMode.multiply : BlendMode.srcOver;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / math.sqrt2, size.height / math.sqrt2);
    canvas.drawRect(const Rect.fromLTRB(-1, -1, 1, 1), _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(StillFog old) => old.daylight != daylight;
}

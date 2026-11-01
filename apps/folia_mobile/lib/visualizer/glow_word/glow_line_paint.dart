import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'glow_line_playback.dart';

// Both source styles use the same outer line opacity/scale/filter; keep a stable content painter while only local tracks change.
abstract class GlowLineContentPainter extends CustomPainter {
  GlowLineContentPainter(this.runtime) : super(repaint: runtime);
  final GlowLinePlayback runtime;
  final _group = Paint();
  @override
  void paint(Canvas canvas, Size size) {
    final line = runtime.line,
        opacity = line.opacity.value.clamp(0.0, 1.0),
        blur = math.max(0.0, line.blur.value);
    if (opacity <= 0) return;
    final center = size.center(Offset.zero), filtered = opacity < 1 || blur > 0;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(line.scale.value);
    canvas.translate(-center.dx, -center.dy);
    if (filtered) {
      _group
        ..color = Color.fromRGBO(255, 255, 255, opacity)
        ..imageFilter = blur <= 0
            ? null
            : ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
      canvas.saveLayer(canvas.getLocalClipBounds(), _group);
    }
    paintContent(canvas, size);
    if (filtered) canvas.restore();
    canvas.restore();
  }

  void paintContent(Canvas canvas, Size size);
}

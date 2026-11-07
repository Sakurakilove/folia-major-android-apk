import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

// Opt in only original static paper materials. Animated appearance/content layers keep their own live repaint paths; native compositing retains the paper's full-DPR display list across camera-only changes.
abstract interface class BravaisStaticSeamSurface {
  Rect cacheBounds(Size size);
}

class BravaisSeamSurfaceCache {
  final _root = LayerHandle<OffsetLayer>();
  (CustomPainter, Size)? _key;
  bool _valid = false;
  void invalidate() => _valid = false;
  void paint(
    PaintingContext context,
    Offset origin,
    CustomPainter surface,
    Size size,
  ) {
    if (surface is! BravaisStaticSeamSurface) {
      clear();
      final canvas = context.canvas;
      canvas.save();
      try {
        canvas.translate(origin.dx, origin.dy);
        surface.paint(canvas, size);
      } finally {
        canvas.restore();
      }
      return;
    }
    final key = (surface, size);
    if (!_valid || key != _key) {
      final bounds = (surface as BravaisStaticSeamSurface).cacheBounds(size),
          recorder = ui.PictureRecorder();
      ui.Picture picture;
      try {
        surface.paint(Canvas(recorder, bounds), size);
        picture = recorder.endRecording();
      } catch (_) {
        recorder.endRecording().dispose();
        rethrow;
      }
      final root = OffsetLayer(offset: origin),
          paper = PictureLayer(bounds)
            ..picture = picture
            ..isComplexHint = true;
      root.append(paper);
      _root.layer = root;
      _key = key;
      _valid = true;
    }
    final layer = _root.layer!..offset = origin;
    context.addLayer(layer);
  }

  void clear() {
    _root.layer = null;
    _valid = false;
    _key = null;
  }
}

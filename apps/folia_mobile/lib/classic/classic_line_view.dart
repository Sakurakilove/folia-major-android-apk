import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../visualizer/glow_word/glow_line_playback.dart';
import '../visualizer/glow_word/glow_word_glyphs.dart';
import '../visualizer/glow_word/glow_word_paint.dart';
import 'classic_flex_layout.dart';
import 'classic_layout.dart';

// The original atomic flex line is laid out only when geometry changes; the line and all words repaint together from one sampled clock.
class ClassicLineView extends StatelessWidget {
  const ClassicLineView({
    super.key,
    required this.runtime,
    required this.glyphs,
    required this.layout,
    required this.text,
  });
  final GlowLinePlayback runtime;
  final List<GlowWordGlyphs> glyphs;
  final ClassicLineLayout layout;
  final String text;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final flex = layoutClassicFlex(math.min(constraints.maxWidth, 1152), [
        for (final g in glyphs) g.size,
      ], layout);
      return Semantics(
        label: text,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ClassicLinePainter(runtime, glyphs, flex),
            size: flex.size,
            child: SizedBox.fromSize(size: flex.size),
          ),
        ),
      );
    },
  );
}

class _ClassicLinePainter extends CustomPainter {
  _ClassicLinePainter(this.runtime, this.glyphs, this.flex)
    : super(repaint: runtime);
  final GlowLinePlayback runtime;
  final List<GlowWordGlyphs> glyphs;
  final ClassicFlexLayout flex;
  final _word = GlowWordPaint(), _group = Paint();
  @override
  void paint(Canvas canvas, Size size) {
    final line = runtime.line,
        opacity = line.opacity.value.clamp(0.0, 1.0),
        blur = math.max(0.0, line.blur.value);
    if (opacity <= 0) return;
    final center = flex.size.center(Offset.zero),
        filtered = opacity < 1 || blur > 0;
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
    for (var i = 0; i < runtime.words.length; i++) {
      final slot = flex.slots[i];
      _word.paint(canvas, runtime.words[i], glyphs[i], slot.topLeft, slot.size);
    }
    if (filtered) canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClassicLinePainter old) =>
      old.runtime != runtime || old.glyphs != glyphs || old.flex != flex;
}

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../visualizer/glow_word/glow_line_playback.dart';
import '../visualizer/glow_word/glow_line_paint.dart';
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

class _ClassicLinePainter extends GlowLineContentPainter {
  _ClassicLinePainter(super.runtime, this.glyphs, this.flex);
  final List<GlowWordGlyphs> glyphs;
  final ClassicFlexLayout flex;
  final _word = GlowWordPaint();
  @override
  void paintContent(Canvas canvas, Size size) {
    for (var i = 0; i < runtime.words.length; i++) {
      final slot = flex.slots[i];
      _word.paint(canvas, runtime.words[i], glyphs[i], slot.topLeft, slot.size);
    }
  }

  @override
  bool shouldRepaint(_ClassicLinePainter old) =>
      old.runtime != runtime || old.glyphs != glyphs || old.flex != flex;
}

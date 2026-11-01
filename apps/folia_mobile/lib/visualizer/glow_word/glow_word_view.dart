import 'package:flutter/widgets.dart';

import 'glow_word_glyphs.dart';
import 'glow_word_motion.dart';
import 'glow_word_paint.dart';

// A word's layout/semantics stay stable while the shared scene invalidation repaints cached full-DPR inputs.
class GlowWordView extends StatelessWidget {
  const GlowWordView({
    super.key,
    required this.motion,
    required this.glyphs,
    required this.frames,
  });
  final GlowWordMotion motion;
  final GlowWordGlyphs glyphs;
  final Listenable frames;
  @override
  Widget build(BuildContext context) => Semantics(
    label: motion.word.text,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _WordPainter(motion, glyphs, frames),
        size: glyphs.size,
        child: SizedBox(width: glyphs.size.width, height: glyphs.size.height),
      ),
    ),
  );
}

class _WordPainter extends CustomPainter {
  _WordPainter(this.motion, this.glyphs, Listenable frames)
    : super(repaint: frames);
  final GlowWordMotion motion;
  final GlowWordGlyphs glyphs;
  final _paint = GlowWordPaint();
  @override
  void paint(Canvas canvas, Size size) => _paint.paint(canvas, motion, glyphs);
  @override
  bool shouldRepaint(_WordPainter old) =>
      old.motion != motion || old.glyphs != glyphs;
}

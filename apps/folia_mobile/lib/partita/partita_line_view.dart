import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../visualizer/glow_word/glow_line_paint.dart';
import '../visualizer/glow_word/glow_line_playback.dart';
import '../visualizer/glow_word/glow_word_paint.dart';
import 'partita_chunk_motion.dart';
import 'partita_flex_layout.dart';
import 'partita_guide_paint.dart';
import 'partita_prepared_line.dart';

// Original column/chunk/guide/word stacking is drawn by one scene painter, sharing the line transition and cached text inputs.
class PartitaLineView extends StatelessWidget {
  const PartitaLineView({
    super.key,
    required this.prepared,
    required this.runtime,
    required this.chunks,
    required this.resolveColor,
  });
  final PartitaPreparedLine prepared;
  final GlowLinePlayback runtime;
  final List<List<PartitaChunkMotion>> chunks;
  final Color Function(String) resolveColor;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final flex = layoutPartitaFlex(
        math.min(1024, constraints.maxWidth),
        prepared,
      );
      return Semantics(
        label: prepared.line.text,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PartitaLinePainter(
              runtime,
              prepared,
              chunks,
              flex,
              resolveColor,
            ),
            size: flex.size,
            child: SizedBox.fromSize(size: flex.size),
          ),
        ),
      );
    },
  );
}

class _PartitaLinePainter extends GlowLineContentPainter {
  _PartitaLinePainter(
    super.runtime,
    this.prepared,
    this.chunks,
    this.flex,
    Color Function(String) resolveColor,
  ) : colors = [
        for (final column in prepared.chunks)
          [
            for (final chunk in column)
              PartitaGuideColors(chunk.activeGuideCss, resolveColor),
          ],
      ];
  final PartitaPreparedLine prepared;
  final List<List<PartitaChunkMotion>> chunks;
  final PartitaFlexLayout flex;
  final List<List<PartitaGuideColors>> colors;
  final _word = GlowWordPaint(), _guide = PartitaGuidePaint(), _group = Paint();
  @override
  void paintContent(Canvas canvas, Size size) {
    for (var c = 0; c < prepared.chunks.length; c++) {
      for (var row = 0; row < prepared.chunks[c].length; row++) {
        final chunk = prepared.chunks[c][row],
            motion = chunks[c][row],
            slot = flex.chunks[c][row];
        final opacity = motion.opacity.value.clamp(0.0, 1.0);
        if (opacity <= 0) continue;
        final center = slot.rect.size.center(Offset.zero);
        canvas.save();
        canvas.translate(
          slot.rect.left + center.dx + motion.x.value,
          slot.rect.top + center.dy + motion.y.value,
        );
        canvas.rotate(motion.rotate.value * math.pi / 180);
        canvas.scale(motion.scale.value);
        canvas.translate(-center.dx, -center.dy);
        if (opacity < 1) {
          canvas.saveLayer(
            canvas.getLocalClipBounds(),
            _group..color = Color.fromRGBO(255, 255, 255, opacity),
          );
        }
        _guide.paint(canvas, slot.rect.size, motion, colors[c][row]);
        for (var i = 0; i < chunk.words.words.length; i++) {
          final wordSlot = slot.words[i];
          _word.paint(
            canvas,
            chunk.words.words[i],
            chunk.words.glyphs[i],
            wordSlot.topLeft,
            wordSlot.size,
          );
        }
        if (opacity < 1) canvas.restore();
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PartitaLinePainter old) =>
      old.prepared != prepared ||
      old.runtime != runtime ||
      old.flex != flex ||
      old.chunks != chunks;
}

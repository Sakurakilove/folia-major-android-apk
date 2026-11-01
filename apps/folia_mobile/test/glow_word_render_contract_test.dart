import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/classic/classic_layout.dart';
import 'package:folia_mobile/lyrics/lyric_types.dart';
import 'package:folia_mobile/rendering/folia_typography.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_word_glyphs.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_word_motion.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_word_paint.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_word_timing.dart';
import 'package:folia_mobile/visualizer/motion/color_value.dart';

// One headless ownership/raster contract: this is not an Android font, original-browser pixel or complete-animation acceptance test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('retained body preserves native color/coverage and full-DPR halo inputs are released once', () async {
    const word = LyricWord('abc', 2, 4),
        color = MotionRgba(20, 150, 210, .4),
        px = 26.0,
        dpr = 2.0;
    final profile = GlowWordRenderProfile(const LyricLine('abc', 2, 4, [word]));
    final motion = GlowWordMotion(
      word: word,
      profile: profile,
      config: const ClassicWordConfig(
        id: 'word',
        x: 0,
        y: 0,
        rotate: 0,
        scale: 1,
        passedRotate: 0,
        marginRight: '0px',
        alignSelf: 'auto',
      ),
      intensity: 'calm',
      baseColor: color,
      activeColor: color,
      rippleScale: 2,
    );
    motion.layout['x']!.jump(0, 0);
    motion.layout['y']!.jump(0, 0);
    motion.layout['rotate']!.jump(0, 0);
    motion.layout['scale']!.jump(1, 0);
    motion.layout['opacity']!.jump(1, 0);
    motion.bodyBlur.jump(0, 0);
    const font = FoliaTypography(families: ['Ahem'], weight: 700, height: 1.22);
    final glyphs = await GlowWordGlyphs.prepare(motion, font, px, dpr);
    for (final glyph in glyphs.glow.whereType<GlowGlyphRaster>()) {
      expect(glyph.image!.width, (glyph.rect.width * dpr).round());
    }
    Future<ui.Image> render(void Function(ui.Canvas) draw) async {
      final recorder = ui.PictureRecorder();
      final output = ui.Canvas(recorder)
        ..scale(dpr)
        ..translate(32, 32);
      draw(output);
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(300, 200);
      } finally {
        picture.dispose();
      }
    }

    try {
      for (final alpha in [1.0, .4]) {
        motion.bodyColor.animate('color', MotionRgba(20, 150, 210, alpha), {
          'duration': 0,
        }, 0);
        final native = TextPainter(
          text: TextSpan(
            text: 'abc',
            style: font.style(
              px,
              color: ui.Color.fromRGBO(20, 150, 210, alpha),
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final actual = await render(
              (canvas) => GlowWordPaint().paint(canvas, motion, glyphs),
            ),
            reference = await render(
              (canvas) => native.paint(canvas, ui.Offset.zero),
            );
        final a = (await actual.toByteData())!,
            b = (await reference.toByteData())!;
        var error = 0, maxAt = 0;
        for (var i = 0; i < a.lengthInBytes; i++) {
          final delta = (a.getUint8(i) - b.getUint8(i)).abs();
          if (delta > error) maxAt = i;
          error = math.max(error, delta);
        }
        final pixel = maxAt ~/ 4 * 4;
        expect(
          error,
          lessThanOrEqualTo(2),
          reason:
              'pixel ${pixel ~/ 4}: ${[for (var j = 0; j < 4; j++) a.getUint8(pixel + j)]} vs ${[for (var j = 0; j < 4; j++) b.getUint8(pixel + j)]}',
        );
        actual.dispose();
        reference.dispose();
        native.dispose();
      }
    } finally {
      glyphs.dispose();
    }
    glyphs.dispose();
    glyphs.dispose();
  });
}

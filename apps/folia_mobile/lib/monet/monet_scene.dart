import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../rendering/repaint_signal.dart';

import 'package:flutter/physics.dart';

import '../lyrics/lyric_document.dart';
import '../playback/playback_controller.dart';
import 'glyph_cache.dart';
import 'monet_motion.dart';

// One bounded painter/clock renders lyric words; immutable masks are shared across all frames.
class MonetScene extends StatefulWidget {
  const MonetScene({
    super.key,
    required this.playback,
    required this.frames,
    required this.seconds,
    required this.program,
  });
  final PlaybackController playback;
  final Listenable frames;
  final double Function() seconds;
  final ui.FragmentProgram program;
  @override
  State<MonetScene> createState() => _MonetSceneState();
}

class _MonetSceneState extends State<MonetScene> {
  final cache = GlyphCache();
  final invalidation = RepaintSignal();
  final motions = <int, _LineMotion>{};
  final shaders = <String, ui.FragmentShader>{};
  final widths = <String, Size>{};
  LyricDocument? document;
  @override
  void dispose() {
    cache.dispose();
    invalidation.dispose();
    for (final shader in shaders.values) {
      shader.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (document != widget.playback.lyrics) {
      document = widget.playback.lyrics;
      motions.clear();
    }
    return GestureDetector(
      onTapUp: (event) {
        final index = motions.entries
            .where((e) => (e.value.lastY - event.localPosition.dy).abs() < 45)
            .firstOrNull
            ?.key;
        if (index != null && index < widget.playback.lyrics.lines.length) {
          widget.playback.seek(widget.playback.lyrics.lines[index].start);
        }
      },
      child: CustomPaint(
        painter: _MonetPainter(
          widget.playback,
          widget.seconds,
          cache,
          motions,
          shaders,
          widths,
          widget.program,
          MediaQuery.devicePixelRatioOf(context),
          Listenable.merge([widget.frames, invalidation, widget.playback]),
          () {
            if (mounted) invalidation.invalidate();
          },
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LineMotion {
  _LineMotion(double y, double scale, double opacity, double blur, this.start)
    : ySpring = SpringSimulation(
        const SpringDescription(mass: .82, stiffness: 142, damping: 28),
        y + 34,
        y,
        0,
      ),
      scaleSpring = SpringSimulation(
        const SpringDescription(mass: .78, stiffness: 150, damping: 30),
        scale * .98,
        scale,
        0,
      ),
      targetY = y,
      targetScale = scale,
      fromOpacity = 0,
      targetOpacity = opacity,
      fromBlur = 5,
      targetBlur = blur;
  SpringSimulation ySpring, scaleSpring;
  double start,
      targetY,
      targetScale,
      fromOpacity,
      targetOpacity,
      fromBlur,
      targetBlur,
      lastY = 0;
  double opacity(double now) => ui.lerpDouble(
    fromOpacity,
    targetOpacity,
    const Cubic(
      .32,
      .72,
      0,
      1,
    ).transform(((now - start) / .28).clamp(0.0, 1.0)),
  )!;
  double blur(double now) => ui.lerpDouble(
    fromBlur,
    targetBlur,
    const Cubic(
      .32,
      .72,
      0,
      1,
    ).transform(((now - start) / .32).clamp(0.0, 1.0)),
  )!;
  void target(
    double y,
    double scale,
    double opacityValue,
    double blurValue,
    double now,
  ) {
    if (y == targetY &&
        scale == targetScale &&
        opacityValue == targetOpacity &&
        blurValue == targetBlur) {
      return;
    }
    final elapsed = math.max(0.0, now - start);
    fromOpacity = opacity(now);
    fromBlur = blur(now);
    ySpring = SpringSimulation(
      const SpringDescription(mass: .82, stiffness: 142, damping: 28),
      ySpring.x(elapsed),
      y,
      ySpring.dx(elapsed),
    );
    scaleSpring = SpringSimulation(
      const SpringDescription(mass: .78, stiffness: 150, damping: 30),
      scaleSpring.x(elapsed),
      scale,
      scaleSpring.dx(elapsed),
    );
    start = now;
    targetY = y;
    targetScale = scale;
    targetOpacity = opacityValue;
    targetBlur = blurValue;
  }
}

class _MonetPainter extends CustomPainter {
  _MonetPainter(
    this.player,
    this.seconds,
    this.cache,
    this.motions,
    this.shaders,
    this.widths,
    this.program,
    this.dpr,
    Listenable repaint,
    this.ready,
  ) : super(repaint: repaint);
  final PlaybackController player;
  final double Function() seconds;
  final GlyphCache cache;
  final Map<int, _LineMotion> motions;
  final Map<String, ui.FragmentShader> shaders;
  final Map<String, Size> widths;
  final ui.FragmentProgram program;
  final double dpr;
  final VoidCallback ready;
  static const font = 32.0;
  @override
  void paint(Canvas canvas, Size size) {
    final lines = player.lyrics.lines;
    if (lines.isEmpty) return;
    final time = player.position, now = seconds();
    final active = player.lyrics.activeIndex(time);
    final anchor = active >= 0
        ? active
        : math.max(0, player.lyrics.latestStartedIndex(time));
    final first = math.max(0, anchor - 2),
        last = math.min(lines.length - 1, anchor + 2);
    final maxWidth = math.max(60.0, size.width - 64);
    final layouts =
        <
          int,
          ({
            List<({LyricWord word, Offset offset, String key, double width})>
            words,
            double height,
          })
        >{};
    final pinned = <String>{};
    for (var i = first; i <= last; i++) {
      var x = 0.0, y = 0.0, rowHeight = font * 1.2;
      final entries =
          <({LyricWord word, Offset offset, String key, double width})>[];
      for (final word in lines[i].words) {
        final key = cache.key(word.text, font, dpr, false, maxWidth);
        pinned.add(key);
        final glyph = cache.get(key);
        final measured = widths.putIfAbsent(key, () {
          final measure = TextPainter(
            text: TextSpan(
              text: word.text,
              style: const TextStyle(
                fontSize: font,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxWidth);
          final value = measure.size;
          measure.dispose();
          return value;
        });
        final width = glyph?.advance ?? measured.width;
        if (x > 0 && x + width > maxWidth) {
          x = 0;
          y += rowHeight;
          rowHeight = font * 1.2;
        }
        rowHeight = math.max(rowHeight, measured.height);
        entries.add((word: word, offset: Offset(x, y), key: key, width: width));
        x += width;
      }
      layouts[i] = (words: entries, height: y + rowHeight + 28);
    }
    cache.pin(pinned);
    // Prewarm the current line first and expose each row atomically, never one word at a time.
    for (final i in [anchor, anchor + 1, anchor - 1, anchor + 2, anchor - 2]) {
      final layout = layouts[i];
      if (layout == null) continue;
      for (final entry in layout.words) {
        if (cache.get(entry.key) == null && !cache.isPreparing(entry.key)) {
          cache
              .prepare(entry.word.text, font, dpr, false, maxWidth)
              .then((_) => ready());
        }
      }
    }
    final ys = <int, double>{anchor: size.height * .46};
    for (var i = anchor - 1; i >= first; i--) {
      ys[i] = ys[i + 1]! - layouts[i]!.height;
    }
    for (var i = anchor + 1; i <= last; i++) {
      ys[i] = ys[i - 1]! + layouts[i - 1]!.height;
    }
    for (var i = first; i <= last; i++) {
      if (layouts[i]!.words.any((entry) => cache.get(entry.key) == null)) {
        continue;
      }
      final status = i == active
          ? 'active'
          : i <= anchor
          ? 'passed'
          : 'waiting';
      final tone = resolveMonetTone(status, i - anchor);
      final motion = motions.putIfAbsent(
        i,
        () => _LineMotion(ys[i]!, tone.scale, tone.opacity, tone.blur, now),
      );
      motion.target(ys[i]!, tone.scale, tone.opacity, tone.blur, now);
      final elapsed = math.max(0.0, now - motion.start),
          y = motion.ySpring.x(elapsed);
      motion.lastY = y;
      canvas.save();
      canvas.translate(32, y);
      canvas.scale(motion.scaleSpring.x(elapsed));
      canvas.saveLayer(
        Rect.fromLTWH(-80, -80, maxWidth + 160, layouts[i]!.height + 160),
        Paint()
          ..color = Colors.white.withValues(
            alpha: motion.opacity(now).clamp(0.0, 1.0),
          )
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: motion.blur(now).clamp(0.0, 20.0),
            sigmaY: motion.blur(now).clamp(0.0, 20.0),
          ),
      );
      for (final entry in layouts[i]!.words) {
        final glyph = cache.get(entry.key);
        if (glyph == null) {
          if (!cache.isPreparing(entry.key)) {
            cache
                .prepare(entry.word.text, font, dpr, false, maxWidth)
                .then((_) => ready());
          }
          continue;
        }
        final shader = shaders.putIfAbsent(
          entry.key,
          () => program.fragmentShader(),
        );
        final word = entry.word;
        final glow = (status == 'active' || status == 'passed')
            ? resolveMonetGlow(time, word.start, word.end, lines[i].end)
            : 0.0;
        final isActive = status == 'active';
        final passed = status == 'passed' || isActive && time > word.end;
        final base = const Color(0xff21393d).withValues(
              alpha: passed
                  ? .98
                  : status == 'waiting'
                  ? .46
                  : .34,
            ),
            ink = const Color(0xff21393d);
        final progress = isActive
            ? clampProgress(
                (time - word.start) / math.max(.001, word.end - word.start),
              )
            : 0.0;
        final fill = isActive
            ? resolveMonetFillWidth(time, word.start, word.end, glyph.offsets)
            : 0.0;
        final values = <double>[
          glyph.size.width,
          glyph.size.height,
          glyph.padding,
          glyph.advance,
          fill,
          progress,
          isActive ? 1 : 0,
          glow,
          .88,
          base.r,
          base.g,
          base.b,
          base.a,
          ink.r,
          ink.g,
          ink.b,
          ink.a,
          (font * .45).clamp(6.0, 16.0),
        ];
        for (var index = 0; index < values.length; index++) {
          shader.setFloat(index, values[index]);
        }
        shader.setImageSampler(0, glyph.glyph);
        shader.setImageSampler(1, glyph.nearGlow);
        shader.setImageSampler(2, glyph.farGlow);
        canvas.save();
        canvas.translate(
          entry.offset.dx - glyph.padding,
          entry.offset.dy - glyph.padding,
        );
        canvas.drawRect(Offset.zero & glyph.size, Paint()..shader = shader);
        canvas.restore();
      }
      canvas.restore();
      canvas.restore();
    }
    widths.removeWhere((key, _) => !pinned.contains(key));
    motions.removeWhere((key, _) => key < first - 1 || key > last + 1);
    for (final key in shaders.keys.toList()) {
      if (!pinned.contains(key)) shaders.remove(key)!.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _MonetPainter old) => true;
}

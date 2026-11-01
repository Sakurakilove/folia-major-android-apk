import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

import '../glyph_cache.dart';
import '../monet_lyrics_model.dart';
import '../monet_motion.dart';
import 'monet_paint_row.dart';

part 'monet_rail_words.dart';
part 'monet_rail_masks.dart';

// Bounded rail rendering: source masks, separate token base/glow/sweep colors, subtitles and z ordering.
class MonetRailPainter extends CustomPainter {
  MonetRailPainter({
    required this.rows,
    required this.cache,
    required this.position,
    required this.seconds,
    required this.primary,
    required this.accent,
    required this.background,
    required this.fontPx,
    required this.glowBuffer,
    required Listenable repaint,
    this.onContentPainted,
    this.onSeek,
  }) : super(repaint: repaint);
  final List<MonetPaintRow> Function() rows;
  final GlyphCache cache;
  final double Function() position, seconds;
  final Color primary, accent, background;
  final double fontPx, glowBuffer;
  final void Function(double)? onSeek;
  final VoidCallback? onContentPainted;
  final _emptyPaint = Paint();
  final _fadePaints = <(bool, double, double), Paint>{};
  final _chorusFills = <(double, double), Paint>{};
  final _chorusLayer = Paint()
    ..imageFilter = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  double? _chorusOpacity;
  Size? _maskSize;
  final _railMask = Paint()..blendMode = BlendMode.dstIn;
  late final _staticShadowPaint = Paint()
    ..colorFilter = ColorFilter.mode(
      background.withValues(alpha: .22),
      BlendMode.srcIn,
    );

  @override
  void paint(Canvas canvas, Size size) {
    final now = seconds(), time = position(), rect = Offset.zero & size;
    var contentReady = true;
    canvas.save();
    canvas.clipRect(rect);
    canvas.saveLayer(rect, _emptyPaint);
    for (final row in rows()) {
      if (row.motion.exited(now)) continue;
      if (row.staticParagraph == null && !row.ready) {
        row.ready = row.runs.every((run) => cache.peek(run.cacheKey) != null);
        if (!row.ready) {
          contentReady = false;
          continue;
        }
      }
      final entry = row.motion.entry,
          layout = entry.layout,
          opacity = row.motion.opacity(now).clamp(0.0, 1.0),
          blur = row.motion.blur(now).clamp(0.0, 20.0);
      final width = math.max(0.0, size.width - glowBuffer * 2),
          active = entry.entry.status == 'active';
      canvas.save();
      canvas.translate(glowBuffer, row.motion.y(now));
      canvas.scale(row.motion.scale(now));
      final bounds = Rect.fromLTWH(
        -glowBuffer - 24,
        -glowBuffer - 24,
        width + 2 * glowBuffer + 48,
        math.max(
              layout.visualHeightPx,
              row.flow.height +
                  layout.textPaddingTopPx +
                  layout.textPaddingBottomPx,
            ) +
            2 * glowBuffer +
            48,
      );
      canvas.saveLayer(bounds, row.updateLayer(opacity, blur));
      if (entry.entry.line.isChorus) {
        _chorus(
          canvas,
          width,
          layout.visualHeightPx,
          row.motion.chorusOpacity(now),
          row.motion.chorusScale(now),
        );
      }
      final textTop = layout.textPaddingTopPx,
          actualHeight = row.flow.height + textTop + layout.textPaddingBottomPx;
      final textRect = Rect.fromLTWH(
        -glowBuffer,
        -glowBuffer,
        width + 2 * glowBuffer,
        (active ? actualHeight : layout.textHeightPx) + 2 * glowBuffer,
      );
      canvas.save();
      canvas.clipRect(textRect);
      canvas.saveLayer(textRect, _emptyPaint);
      if (row.staticParagraph != null) {
        row.staticParagraph!.paint(canvas, Offset(0, textTop));
      } else {
        row.staticTokens?.paint(canvas, Offset(0, textTop));
        for (final run in row.runs) {
          _word(canvas, row, run, time, textTop);
        }
      }
      if (!active && layout.isTextClipped) {
        final bottom = textTop + layout.textContentHeightPx,
            fade = math.max(fontPx * .55, 12.0);
        _verticalMask(canvas, textRect, math.max(bottom - fade, 0), bottom);
      }
      if (layout.isTextOverflowingWidth) {
        final fade = math.max(fontPx * .9, 24.0), right = width + glowBuffer;
        _horizontalMask(canvas, textRect, right - fade, right);
      }
      canvas.restore();
      canvas.restore();
      var top = active ? actualHeight : layout.textHeightPx;
      for (var i = 0; i < layout.subtitleTracks.length; i++) {
        final track = layout.subtitleTracks[i],
            motion = row.motion.subtitleMotion(i, now);
        final trackRect = Rect.fromLTWH(
          -glowBuffer,
          top,
          width + 2 * glowBuffer,
          track.heightPx,
        );
        canvas.save();
        canvas.translate(0, motion.y);
        canvas.clipRect(trackRect);
        canvas.saveLayer(trackRect, row.subtitleLayer(i, motion.opacity));
        row.subtitles[i].paint(canvas, Offset(0, top + track.paddingTopPx));
        if (track.isClipped) {
          _verticalMask(
            canvas,
            trackRect,
            trackRect.bottom - math.max(track.fontPx * .65, 10),
            trackRect.bottom,
          );
        }
        canvas.restore();
        canvas.restore();
        top += track.heightPx;
      }
      canvas.restore();
      canvas.restore();
    }
    if (_maskSize != size) {
      _maskSize = size;
      _railMask.shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [
          Color(0x00ffffff),
          Color(0xffffffff),
          Color(0xffffffff),
          Color(0x00ffffff),
        ],
        const [0, .11, .88, 1],
      );
    }
    canvas.drawRect(rect, _railMask);
    canvas.restore();
    canvas.restore();
    if (contentReady) onContentPainted?.call();
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final row in rows())
          if (!row.motion.exiting)
            CustomPainterSemantics(
              key: ValueKey(row.motion.entry.entry.key),
              rect: Rect.fromLTWH(
                glowBuffer,
                row.motion.entry.y,
                math.max(0, size.width - 2 * glowBuffer),
                row.motion.entry.scaledHeight,
              ),
              properties: SemanticsProperties(
                textDirection: TextDirection.ltr,
                button: onSeek != null,
                label: [
                  row.motion.entry.entry.line.text,
                  ...row.motion.entry.layout.subtitleTracks.map((t) => t.text),
                ].join('\n'),
                onTap: onSeek == null
                    ? null
                    : () => onSeek!(row.motion.entry.entry.line.start),
              ),
            ),
      ];
  @override
  bool shouldRepaint(MonetRailPainter old) => true;
  @override
  bool shouldRebuildSemantics(MonetRailPainter oldDelegate) => true;
}

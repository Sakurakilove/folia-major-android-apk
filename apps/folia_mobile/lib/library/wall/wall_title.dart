import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../rendering/css_text.dart';
import '../../rendering/js_text.dart';

// Native title preparation happens against the destination column, never the animated rectangle. Full accessible text is retained separately from the preview.
class WallTitle extends LeafRenderObjectWidget {
  const WallTitle({
    super.key,
    required this.title,
    required this.style,
    required this.targetWidth,
    required this.fontsEpoch,
    this.maxLines = 3,
    this.direction = TextDirection.ltr,
    this.locale,
  });
  final String title;
  final TextStyle style;
  final double targetWidth;
  final int fontsEpoch, maxLines;
  final TextDirection direction;
  final Locale? locale;
  @override
  RenderWallTitle createRenderObject(BuildContext context) =>
      RenderWallTitle(this);
  @override
  void updateRenderObject(BuildContext context, RenderWallTitle renderObject) =>
      renderObject.specification = this;
}

class _TitleFitKey {
  const _TitleFitKey(
    this.text,
    this.style,
    this.width,
    this.epoch,
    this.maxLines,
    this.direction,
    this.locale,
  );
  final String text;
  final TextStyle style;
  final double width;
  final int epoch, maxLines;
  final TextDirection direction;
  final Locale? locale;
  @override
  int get hashCode =>
      Object.hash(text, style, width, epoch, maxLines, direction, locale);
  @override
  bool operator ==(Object other) =>
      other is _TitleFitKey &&
      text == other.text &&
      style == other.style &&
      width == other.width &&
      epoch == other.epoch &&
      maxLines == other.maxLines &&
      direction == other.direction &&
      locale == other.locale;
}

final _fits = <_TitleFitKey, String>{};

// The original DOM corrector's grapheme-prefix search is retained; native line breaking/fonts and balanced wrap still require the final browser comparison.
String _fitTitle(_TitleFitKey key, TextPainter probe) {
  final cached = _fits.remove(key);
  if (cached != null) {
    _fits[key] = cached;
    return cached;
  }
  final limit =
      (key.style.fontSize ?? 14) * (key.style.height ?? 1.5) * key.maxLines + 1;
  bool fits(String value) {
    probe.text = TextSpan(text: cssNormalText(value), style: key.style);
    probe.layout(maxWidth: key.width);
    return probe.height <= limit;
  }

  var fitted = key.text;
  if (!fits(key.text)) {
    final graphemes = key.text.characters.toList(growable: false);
    String candidate(int count) =>
        '${jsTrimEnd(graphemes.take(count).join())}…';
    var low = 0, high = graphemes.length;
    while (low < high) {
      final middle = ((low + high) / 2).ceil();
      if (fits(candidate(middle))) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    fitted = candidate(low);
  }
  _fits[key] = fitted;
  while (_fits.length > 512) {
    _fits.remove(_fits.keys.first);
  }
  return fitted;
}

class RenderWallTitle extends RenderBox {
  RenderWallTitle(this._specification);
  WallTitle _specification;
  TextPainter? _paragraph;
  double _paintWidth = 0, _paintHeight = 0;
  set specification(WallTitle value) {
    final old = _specification;
    _specification = value;
    if (old.title == value.title &&
        old.style == value.style &&
        old.targetWidth == value.targetWidth &&
        old.fontsEpoch == value.fontsEpoch &&
        old.maxLines == value.maxLines &&
        old.direction == value.direction &&
        old.locale == value.locale) {
      return;
    }
    _paragraph?.dispose();
    _paragraph = null;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  void _prepare() {
    if (_paragraph != null) return;
    final s = _specification, width = math.max(0.0, s.targetWidth);
    final painter = TextPainter(
      textDirection: s.direction,
      locale: s.locale,
      textScaler: TextScaler.noScaling,
    );
    if (width == 0) {
      painter.text = TextSpan(text: '', style: s.style);
      painter.layout();
      _paintWidth = _paintHeight = 0;
    } else {
      final key = _TitleFitKey(
        s.title,
        s.style.copyWith(color: const Color(0xff000000), shadows: const []),
        width,
        s.fontsEpoch,
        s.maxLines,
        s.direction,
        s.locale,
      );
      final fitted = _fitTitle(key, painter);
      painter.text = TextSpan(text: cssNormalText(fitted), style: s.style);
      painter.layout(maxWidth: width);
      final lines = painter.computeLineMetrics().length;
      // CSS text-wrap:balance keeps the existing line count and tightens the line width; long titles above six lines remain ordinary wrap.
      if (lines > 1 && lines <= 6) {
        var low = 0.0, high = width;
        while (high - low > 1 / 64) {
          final middle = (low + high) / 2;
          painter.layout(maxWidth: middle);
          if (painter.computeLineMetrics().length <= lines) {
            high = middle;
          } else {
            low = middle;
          }
        }
        painter.layout(maxWidth: high);
      }
      _paintWidth = width;
      _paintHeight = painter.height;
    }
    _paragraph = painter;
  }

  @override
  void performLayout() {
    _prepare();
    size = constraints.constrain(Size(_paintWidth, _paintHeight));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _prepare();
    return constraints.constrain(Size(_paintWidth, _paintHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _prepare();
    // Matching padding and negative block margins expand the paint area without shifting the anchored copy.
    final padding = (_specification.style.fontSize ?? 14) * .14;
    context.canvas.save();
    context.canvas.clipRect(
      Rect.fromLTWH(
        offset.dx,
        offset.dy - padding,
        size.width,
        size.height + 2 * padding,
      ),
    );
    _paragraph!.paint(context.canvas, offset);
    context.canvas.restore();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _specification.title
      ..textDirection = _specification.direction;
  }

  @override
  void dispose() {
    _paragraph?.dispose();
    super.dispose();
  }
}

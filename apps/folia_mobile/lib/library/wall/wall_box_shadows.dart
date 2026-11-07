import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../rendering/css_color.dart';
import 'wall_css_paint.dart';

// CSS box-shadow uses sigma=blur/2, unlike Flutter BoxShadow's legacy radius conversion. Outside shadows never fill the transparent poster interior.
class WallBoxShadow {
  const WallBoxShadow(
    this.color, {
    this.offset = Offset.zero,
    this.blur = 0,
    this.spread = 0,
    this.modern = false,
    this.inset = false,
  });
  final Color color;
  final Offset offset;
  final double blur, spread;
  final bool modern, inset;
  static WallBoxShadow interpolate(
    WallBoxShadow a,
    WallBoxShadow b,
    double p,
  ) => WallBoxShadow(
    CssColorValue.interpolate(
      a.modern ? CssColorValue.modern(a.color) : CssColorValue.legacy(a.color),
      b.modern ? CssColorValue.modern(b.color) : CssColorValue.legacy(b.color),
      p,
    ).color,
    offset: Offset.lerp(a.offset, b.offset, p)!,
    blur: a.blur + (b.blur - a.blur) * p,
    spread: a.spread + (b.spread - a.spread) * p,
    modern: a.modern || b.modern,
    inset: a.inset,
  );
  @override
  bool operator ==(Object other) =>
      other is WallBoxShadow &&
      color == other.color &&
      offset == other.offset &&
      blur == other.blur &&
      spread == other.spread &&
      modern == other.modern &&
      inset == other.inset;
  @override
  int get hashCode => Object.hash(color, offset, blur, spread, modern, inset);
  double get extent => inset
      ? 0
      : math.max(
          0,
          blur * 1.5 + spread + math.max(offset.dx.abs(), offset.dy.abs()),
        );
  void paint(Canvas canvas, Rect rect) {
    if (color.a == 0) return;
    if (inset) {
      paintWallInsetShadow(
        canvas,
        rect,
        color,
        blur: blur,
        spread: spread,
        offset: offset,
      );
      return;
    }
    final paint = Paint()..color = color;
    if (blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);
    }
    canvas.drawRect(rect.shift(offset).inflate(spread), paint);
  }
}

// CSS pads a shorter shadow list with transparent, zero-size entries at its end; entries are never paired by semantic role.
class WallShadowList {
  const WallShadowList(this.shadows);
  final List<WallBoxShadow> shadows;
  bool compatible(WallShadowList other) {
    for (var i = 0; i < math.min(shadows.length, other.shadows.length); i++) {
      if (shadows[i].inset != other.shadows[i].inset) return false;
    }
    return true;
  }

  static WallShadowList interpolate(
    WallShadowList a,
    WallShadowList b,
    double p,
  ) {
    assert(a.compatible(b));
    return WallShadowList(
      List.generate(
        math.max(a.shadows.length, b.shadows.length),
        (i) => WallBoxShadow.interpolate(
          i < a.shadows.length
              ? a.shadows[i]
              : WallBoxShadow(
                  const Color(0x00000000),
                  inset: b.shadows[i].inset,
                ),
          i < b.shadows.length
              ? b.shadows[i]
              : WallBoxShadow(
                  const Color(0x00000000),
                  inset: a.shadows[i].inset,
                ),
          p,
        ),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WallShadowList && listEquals(shadows, other.shadows);
  @override
  int get hashCode => Object.hashAll(shadows);
}

class WallBoxShadows extends SingleChildRenderObjectWidget {
  const WallBoxShadows({super.key, required this.shadows, super.child});
  final ValueListenable<List<WallBoxShadow>> shadows;
  @override
  RenderWallBoxShadows createRenderObject(BuildContext context) =>
      RenderWallBoxShadows(shadows);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderWallBoxShadows renderObject,
  ) => renderObject.shadows = shadows;
}

class RenderWallBoxShadows extends RenderProxyBox {
  RenderWallBoxShadows(this._shadows);
  ValueListenable<List<WallBoxShadow>> _shadows;
  set shadows(ValueListenable<List<WallBoxShadow>> value) {
    if (identical(value, _shadows)) return;
    if (attached) _shadows.removeListener(markNeedsPaint);
    _shadows = value;
    if (attached) _shadows.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  Rect get paintBounds => (Offset.zero & size).inflate(
    _shadows.value.fold(
      0.0,
      (value, shadow) =>
          shadow.color.a == 0 ? value : math.max(value, shadow.extent),
    ),
  );
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _shadows.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _shadows.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bounds = offset & size;
    context.canvas.save();
    context.canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(paintBounds.shift(offset).inflate(1))
        ..addRect(bounds),
    );
    for (final shadow in _shadows.value.reversed) {
      if (!shadow.inset) shadow.paint(context.canvas, bounds);
    }
    context.canvas.restore();
    super.paint(context, offset);
    for (final shadow in _shadows.value.reversed) {
      if (shadow.inset) shadow.paint(context.canvas, bounds);
    }
  }
}

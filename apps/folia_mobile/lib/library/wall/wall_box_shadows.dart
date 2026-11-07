import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// CSS box-shadow uses sigma=blur/2, unlike Flutter BoxShadow's legacy radius conversion. Outside shadows never fill the transparent poster interior.
class WallBoxShadow {
  const WallBoxShadow(
    this.color, {
    this.offset = Offset.zero,
    this.blur = 0,
    this.spread = 0,
  });
  final Color color;
  final Offset offset;
  final double blur, spread;
  double get extent => math.max(
    0,
    blur * 1.5 + spread + math.max(offset.dx.abs(), offset.dy.abs()),
  );
  void paint(Canvas canvas, Rect rect) {
    if (color.a == 0) return;
    final paint = Paint()..color = color;
    if (blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);
    }
    canvas.drawRect(rect.shift(offset).inflate(spread), paint);
  }
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
      shadow.paint(context.canvas, bounds);
    }
    context.canvas.restore();
    super.paint(context, offset);
  }
}

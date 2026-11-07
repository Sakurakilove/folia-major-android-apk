import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'bravais_tile_motion.dart';
import 'bravais_tile_types.dart';
import '../../wall/wall_paint_boundary.dart';
import '../../wall/wall_overflow_hit_test.dart';

// Only a source face commit rebuilds card content. Transform/opacity frames update this native proxy over the retained full-resolution child.
class BravaisAnimatedFace<T> extends StatelessWidget {
  const BravaisAnimatedFace({
    super.key,
    required this.motion,
    required this.builder,
  });
  final BravaisTileMotion<T> motion;
  final Widget Function(BuildContext, BravaisTileFace<T>) builder;
  @override
  Widget build(BuildContext context) => BravaisFaceLayer(
    motion: motion,
    child: ValueListenableBuilder(
      valueListenable: motion.face,
      builder: (context, face, _) =>
          WallPaintBoundary(child: builder(context, face)),
    ),
  );
}

class BravaisFaceLayer extends SingleChildRenderObjectWidget {
  const BravaisFaceLayer({super.key, required this.motion, super.child});
  final BravaisTileMotion<dynamic> motion;
  @override
  RenderBravaisFace createRenderObject(BuildContext context) =>
      RenderBravaisFace(motion);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisFace renderObject,
  ) => renderObject.motion = motion;
}

class RenderBravaisFace extends RenderProxyBox with WallOverflowHitTest {
  RenderBravaisFace(this._motion);
  BravaisTileMotion<dynamic> _motion;
  Matrix4? _matrix;
  final _transform = LayerHandle<TransformLayer>(),
      _opacity = LayerHandle<ColorFilterLayer>();
  set motion(BravaisTileMotion<dynamic> value) {
    if (identical(value, _motion)) return;
    if (attached) _motion.removeListener(_changed);
    _motion = value;
    if (attached) _motion.addListener(_changed);
    _changed();
  }

  void _changed() {
    _matrix = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;
  @override
  Rect get paintBounds => child == null
      ? Offset.zero & size
      : MatrixUtils.transformRect(transform, child!.paintBounds);
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _matrix = null;
    _motion.addListener(_changed);
  }

  @override
  void detach() {
    _motion.removeListener(_changed);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _matrix = null;
  }

  Matrix4 get transform {
    if (_matrix != null) return _matrix!;
    final sample = _motion.sample, matrix = Matrix4.identity();
    if (sample.transformEffect) {
      final cx = size.width / 2, cy = size.height / 2;
      matrix.translateByDouble(cx, cy, 0, 1);
      if (sample.rotateY != 0) {
        matrix.multiply(Matrix4.identity()..setEntry(3, 2, -1 / 1400));
        matrix.rotateY(sample.rotateY * math.pi / 180);
      } else {
        matrix
          ..translateByDouble(0, sample.y, 0, 1)
          ..scaleByDouble(sample.scale, sample.scale, 1, 1);
      }
      matrix.translateByDouble(-cx, -cy, 0, 1);
    }
    return _matrix = matrix;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final alpha = _motion.sample.opacity;
    if (alpha <= 0) {
      _transform.layer = null;
      _opacity.layer = null;
      return;
    }
    void paintFace(PaintingContext context, Offset offset) {
      // Matrix alpha keeps continuous compositor opacity instead of rounding its animation to an 8-bit layer field.
      if (alpha < 1) {
        final filter = ColorFilter.matrix([
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          alpha,
          0,
        ]);
        _opacity.layer = context.pushColorFilter(
          offset,
          filter,
          super.paint,
          oldLayer: _opacity.layer,
        );
      } else {
        _opacity.layer = null;
        super.paint(context, offset);
      }
    }

    if (_motion.sample.transformEffect) {
      _transform.layer = context.pushTransform(
        needsCompositing,
        offset,
        transform,
        paintFace,
        oldLayer: _transform.layer,
      );
    } else {
      _transform.layer = null;
      paintFace(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: transform,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(this.transform);
  @override
  void dispose() {
    _transform.layer = null;
    _opacity.layer = null;
    super.dispose();
  }
}

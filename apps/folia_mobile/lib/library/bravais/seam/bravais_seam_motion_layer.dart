import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'bravais_seam_content_motion.dart';
import 'bravais_seam_flight.dart';

// Retain the full-resolution seam subtree while its content layer rotates/fades; outgoing content is inert and excluded from focus/semantics until the face commit.
class BravaisSeamMotionLayer extends StatelessWidget {
  const BravaisSeamMotionLayer({
    super.key,
    required this.motion,
    required this.child,
    this.axis = BravaisSeamFlipAxis.y,
  });
  final BravaisSeamContentMotion<dynamic> motion;
  final BravaisSeamFlipAxis axis;
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: motion.leavingValue,
    child: _SeamFlightLayer(motion: motion, axis: axis, child: child),
    builder: (_, leaving, child) => IgnorePointer(
      ignoring: leaving,
      child: ExcludeFocus(
        excluding: leaving,
        child: ExcludeSemantics(excluding: leaving, child: child),
      ),
    ),
  );
}

class _SeamFlightLayer extends SingleChildRenderObjectWidget {
  const _SeamFlightLayer({
    required this.motion,
    required this.axis,
    super.child,
  });
  final BravaisSeamContentMotion<dynamic> motion;
  final BravaisSeamFlipAxis axis;
  @override
  RenderBravaisSeamFlight createRenderObject(BuildContext context) =>
      RenderBravaisSeamFlight(motion, axis);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisSeamFlight renderObject,
  ) => renderObject.update(motion, axis);
}

class RenderBravaisSeamFlight extends RenderProxyBox {
  RenderBravaisSeamFlight(this._motion, this._axis);
  BravaisSeamContentMotion<dynamic> _motion;
  BravaisSeamFlipAxis _axis;
  final _transform = LayerHandle<TransformLayer>(),
      _opacity = LayerHandle<ColorFilterLayer>();
  Matrix4? _matrix;
  void update(
    BravaisSeamContentMotion<dynamic> motion,
    BravaisSeamFlipAxis axis,
  ) {
    if (identical(motion, _motion) && axis == _axis) return;
    if (attached) _motion.removeListener(_changed);
    _motion = motion;
    _axis = axis;
    if (attached) _motion.addListener(_changed);
    _changed();
  }

  void _changed() {
    _matrix = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Matrix4 get transform {
    if (_matrix != null) return _matrix!;
    final matrix = Matrix4.identity(), sample = _motion.sample;
    if (sample.transformEffect) {
      matrix
        ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
        ..multiply(Matrix4.identity()..setEntry(3, 2, -1 / 1400));
      if (_axis == BravaisSeamFlipAxis.x) {
        matrix.rotateX(sample.degrees * math.pi / 180);
      } else {
        matrix.rotateY(sample.degrees * math.pi / 180);
      }
      matrix.translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
    }
    return _matrix = matrix;
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

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final alpha = _motion.sample.opacity;
    if (alpha <= 0) {
      _transform.layer = null;
      _opacity.layer = null;
      return;
    }
    void paintChild(PaintingContext context, Offset offset) {
      if (alpha < 1) {
        _opacity.layer = context.pushColorFilter(
          offset,
          ColorFilter.matrix([
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
          ]),
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
        paintChild,
        oldLayer: _transform.layer,
      );
    } else {
      _transform.layer = null;
      paintChild(context, offset);
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

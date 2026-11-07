import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../bravais_frame.dart';
import '../poster_safe_area.dart';

// Only .bravais-poster-ui scales; its ground/grain/color fields stay outside. Use the settled target opening and viewport height, not a moving clipped width or padded body height.
class BravaisPosterSafeLayer extends SingleChildRenderObjectWidget {
  const BravaisPosterSafeLayer({
    super.key,
    required this.frame,
    required this.targetWidth,
    required this.viewportHeight,
    super.child,
  });
  final ValueListenable<BravaisFrame> frame;
  final double targetWidth, viewportHeight;
  @override
  RenderBravaisPosterSafe createRenderObject(BuildContext context) =>
      RenderBravaisPosterSafe(frame, targetWidth, viewportHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisPosterSafe renderObject,
  ) => renderObject.update(frame, targetWidth, viewportHeight);
}

class RenderBravaisPosterSafe extends RenderProxyBox {
  RenderBravaisPosterSafe(this._frame, this._targetWidth, this._viewportHeight);
  ValueListenable<BravaisFrame> _frame;
  double _targetWidth, _viewportHeight;
  double? _degrees;
  Matrix4? _matrix;
  final _layer = LayerHandle<TransformLayer>();
  void update(
    ValueListenable<BravaisFrame> frame,
    double width,
    double height,
  ) {
    if (!identical(frame, _frame)) {
      if (attached) _frame.removeListener(_frameChanged);
      _frame = frame;
      if (attached) _frame.addListener(_frameChanged);
      _matrix = null;
      _degrees = null;
    }
    if (_targetWidth != width || _viewportHeight != height) {
      _targetWidth = width;
      _viewportHeight = height;
      _matrix = null;
    }
    if (_matrix == null) _changed();
  }

  void _changed() {
    _matrix = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _frameChanged() {
    final deg = _frame.value.tilt.deg;
    if (_degrees == deg) return;
    _degrees = deg;
    _changed();
  }

  Matrix4 get transform {
    if (_matrix != null) return _matrix!;
    final safe = posterSafeArea(
          _targetWidth,
          _viewportHeight,
          _frame.value.tilt.deg,
        ),
        scale = double.parse(safe.scale.toStringAsFixed(4)),
        y = double.parse(safe.offsetY.toStringAsFixed(1));
    return _matrix = Matrix4.identity()
      ..translateByDouble(size.width, y, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-size.width, 0, 0, 1);
  }

  @override
  bool get alwaysNeedsCompositing => child != null;
  @override
  Rect get paintBounds => child == null
      ? Offset.zero & size
      : MatrixUtils.transformRect(transform, child!.paintBounds);
  @override
  void performLayout() {
    super.performLayout();
    _matrix = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _frame.addListener(_frameChanged);
    _frameChanged();
  }

  @override
  void detach() {
    _frame.removeListener(_frameChanged);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      super.paint,
      oldLayer: _layer.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: transform,
        position: position,
        hitTest: (result, local) =>
            super.hitTestChildren(result, position: local),
      );
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(this.transform);
  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

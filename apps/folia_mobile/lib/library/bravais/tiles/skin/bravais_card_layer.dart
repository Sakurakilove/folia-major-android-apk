import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../wall/wall_css_filter.dart';
import 'bravais_card_motion.dart';
import '../bravais_tile_motion.dart';

// CSS transforms are the underlying value of a WAAPI transform animation, not another scale multiplied into the flip/wave.
class BravaisCardLayer extends SingleChildRenderObjectWidget {
  const BravaisCardLayer({
    super.key,
    required this.motion,
    this.flight,
    super.child,
  });
  final BravaisCardMotion motion;
  final BravaisTileMotion<dynamic>? flight;
  @override
  RenderBravaisCard createRenderObject(BuildContext context) =>
      RenderBravaisCard(motion, flight);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisCard renderObject,
  ) => renderObject.update(motion, flight);
}

class RenderBravaisCard extends RenderProxyBox {
  RenderBravaisCard(this._motion, this._flight);
  BravaisCardMotion _motion;
  BravaisTileMotion<dynamic>? _flight;
  final _transform = LayerHandle<TransformLayer>(),
      _filterLayer = LayerHandle<ImageFilterLayer>();
  Matrix4? _matrix;
  WallCssFilter? _lastFilter;
  double? _lastAlpha;
  ui.ImageFilter? _nativeFilter;
  void update(BravaisCardMotion motion, BravaisTileMotion<dynamic>? flight) {
    if (identical(motion, _motion) && identical(flight, _flight)) return;
    if (attached) _listen(false);
    _motion = motion;
    _flight = flight;
    if (attached) _listen(true);
    _changed();
  }

  void _listen(bool listen) {
    if (listen) {
      _motion.addListener(_changed);
      _flight?.addListener(_changed);
    } else {
      _motion.removeListener(_changed);
      _flight?.removeListener(_changed);
    }
  }

  void _changed() {
    _matrix = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Matrix4 get transform {
    if (_matrix != null) return _matrix!;
    final matrix = Matrix4.identity();
    if (!(_flight?.sample.transformEffect ?? false)) {
      final x = _motion.value(BravaisCardPhase.x),
          y = _motion.value(BravaisCardPhase.y);
      matrix
        ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
        ..scaleByDouble(x, y, 1, 1)
        ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
    }
    return _matrix = matrix;
  }

  ui.ImageFilter? get nativeFilter {
    final filter = _motion.filter,
        alpha = (_flight?.sample.opacityEffect ?? false)
            ? 1.0
            : _motion.opacity;
    if (filter == _lastFilter && alpha == _lastAlpha) return _nativeFilter;
    _lastFilter = filter;
    _lastAlpha = alpha;
    var result = filter.native;
    if (alpha < 1) {
      final opacity = ui.ColorFilter.matrix([
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
      result = result == null
          ? opacity
          : ui.ImageFilter.compose(outer: opacity, inner: result);
    }
    return _nativeFilter = result;
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
    _listen(true);
  }

  @override
  void detach() {
    _listen(false);
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
    void paintFiltered(PaintingContext context, Offset offset) {
      final filter = nativeFilter;
      if (filter == null) {
        _filterLayer.layer = null;
        super.paint(context, offset);
      } else {
        final layer = _filterLayer.layer ?? ImageFilterLayer();
        layer
          ..imageFilter = filter
          ..offset = Offset.zero;
        _filterLayer.layer = layer;
        context.pushLayer(layer, super.paint, offset);
      }
    }

    _transform.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      paintFiltered,
      oldLayer: _transform.layer,
    );
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
    _filterLayer.layer = null;
    super.dispose();
  }
}

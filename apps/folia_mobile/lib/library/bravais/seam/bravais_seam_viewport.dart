import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../bravais_frame.dart';

part 'bravais_seam_viewport_paint.dart';

// The opening changes only clipping/paint geometry. Its rendered content keeps its own width throughout the outgoing flip, exactly as the original absolute-positioned .bravais-seam-content.
class BravaisSeamViewport extends SingleChildRenderObjectWidget {
  const BravaisSeamViewport({
    super.key,
    required this.frame,
    required this.contentWidth,
    required this.surface,
    this.underlay,
    this.overlay,
    this.poster = false,
    super.child,
  });
  final ValueListenable<BravaisFrame> frame;
  final double contentWidth;
  final CustomPainter surface;
  final CustomPainter? underlay, overlay;
  final bool poster;
  @override
  RenderBravaisSeamViewport createRenderObject(BuildContext context) =>
      RenderBravaisSeamViewport(
        frame,
        contentWidth,
        surface,
        poster,
        underlay: underlay,
        overlay: overlay,
      );
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisSeamViewport renderObject,
  ) => renderObject.update(
    frame,
    contentWidth,
    surface,
    poster,
    underlay: underlay,
    overlay: overlay,
  );
}

class RenderBravaisSeamViewport extends RenderProxyBox {
  RenderBravaisSeamViewport(
    this._frame,
    this._contentWidth,
    this._surface,
    this._poster, {
    this._underlay,
    this._overlay,
  });
  ValueListenable<BravaisFrame> _frame;
  double _contentWidth;
  CustomPainter _surface;
  CustomPainter? _underlay, _overlay;
  bool _poster;
  Matrix4? _tilt;
  final _outerClip = LayerHandle<ClipRectLayer>(),
      _paperClip = LayerHandle<ClipRectLayer>(),
      _transform = LayerHandle<TransformLayer>(),
      _opacity = LayerHandle<ColorFilterLayer>();
  void update(
    ValueListenable<BravaisFrame> frame,
    double contentWidth,
    CustomPainter surface,
    bool poster, {
    CustomPainter? underlay,
    CustomPainter? overlay,
  }) {
    if (!identical(frame, _frame)) {
      if (attached) _frame.removeListener(_changed);
      _frame = frame;
      if (attached) _frame.addListener(_changed);
      _changed();
    }
    if (_contentWidth != contentWidth) {
      _contentWidth = contentWidth;
      markNeedsLayout();
    }
    if (!identical(surface, _surface)) {
      if (attached) _surface.removeListener(markNeedsPaint);
      _surface = surface;
      if (attached) _surface.addListener(markNeedsPaint);
      markNeedsPaint();
    }
    if (!identical(underlay, _underlay) || !identical(overlay, _overlay)) {
      if (attached) {
        _underlay?.removeListener(markNeedsPaint);
        _overlay?.removeListener(markNeedsPaint);
      }
      _underlay = underlay;
      _overlay = overlay;
      if (attached) {
        _underlay?.addListener(markNeedsPaint);
        _overlay?.addListener(markNeedsPaint);
      }
      markNeedsPaint();
    }
    if (_poster != poster) {
      _poster = poster;
      _changed();
    }
  }

  void _changed() {
    _tilt = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Rect get paperBounds {
    final frame = _frame.value, bleed = _poster ? size.height * .4 : 0.0;
    return Rect.fromLTWH(
      frame.seamX - frame.seamWidth / 2,
      -bleed,
      frame.seamWidth,
      size.height + 2 * bleed,
    );
  }

  Offset get contentOffset => Offset(_frame.value.seamX - _contentWidth / 2, 0);
  Matrix4 get tiltTransform {
    if (_tilt != null) return _tilt!;
    final tilt = _frame.value.tilt, matrix = Matrix4.identity();
    if (tilt.deg.abs() >= .001) {
      matrix
        ..translateByDouble(tilt.pivotX, tilt.pivotY, 0, 1)
        ..rotateZ(tilt.deg * math.pi / 180)
        ..translateByDouble(-tilt.pivotX, -tilt.pivotY, 0, 1);
    }
    return _tilt = matrix;
  }

  @override
  bool get alwaysNeedsCompositing => true;
  @override
  void paint(PaintingContext context, Offset offset) =>
      paintSeam(context, offset);
  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth && constraints.hasBoundedHeight);
    size = constraints.biggest;
    child?.layout(BoxConstraints.tight(Size(_contentWidth, size.height)));
    _tilt = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _frame.addListener(_changed);
    _surface.addListener(markNeedsPaint);
    _underlay?.addListener(markNeedsPaint);
    _overlay?.addListener(markNeedsPaint);
    _changed();
  }

  @override
  void detach() {
    _frame.removeListener(_changed);
    _surface.removeListener(markNeedsPaint);
    _underlay?.removeListener(markNeedsPaint);
    _overlay?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_frame.value.seamVisible || child == null) return false;
    return result.addWithPaintTransform(
      transform: tiltTransform,
      position: position,
      hitTest: (result, local) =>
          paperBounds.contains(local) &&
          result.addWithPaintOffset(
            offset: contentOffset,
            position: local,
            hitTest: (result, point) => child!.hitTest(result, position: point),
          ),
    );
  }

  @override
  bool hitTestSelf(Offset position) {
    if (!_frame.value.seamVisible) return false;
    final inverse = Matrix4.tryInvert(tiltTransform);
    return inverse != null &&
        paperBounds.contains(MatrixUtils.transformPoint(inverse, position));
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform
    ..multiply(tiltTransform)
    ..translateByDouble(contentOffset.dx, 0, 0, 1);
  @override
  Rect? describeSemanticsClip(RenderObject? child) => MatrixUtils.transformRect(
    tiltTransform,
    paperBounds,
  ).intersect(Offset.zero & size);
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_frame.value.seamVisible) super.visitChildrenForSemantics(visitor);
  }

  @override
  void dispose() {
    _outerClip.layer = null;
    _paperClip.layer = null;
    _transform.layer = null;
    _opacity.layer = null;
    super.dispose();
  }
}

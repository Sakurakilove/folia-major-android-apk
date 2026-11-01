import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../wall/wall_slots.dart';
import '../wall/wall_types.dart';
import '../wall/wall_view.dart';
import 'bravais_frame.dart';
import 'bravais_plate_painter.dart';

part 'bravais_viewport_widget.dart';

// Native camera invalidation changes paint only; finite focus reflows relayout just the children whose sizes changed.
class RenderBravaisViewport extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, BravaisSeatData>,
        RenderBoxContainerDefaultsMixin<RenderBox, BravaisSeatData> {
  RenderBravaisViewport(this._frame, this._dpr);
  ValueListenable<BravaisFrame> _frame;
  double _dpr;
  BravaisPlatePainter? _plates;
  set plates(BravaisPlatePainter? value) {
    if (identical(value, _plates)) return;
    if (attached) _plates?.removeListener(markNeedsPaint);
    _plates = value;
    if (attached) _plates?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  ValueListenable<Map<String, WallRect>>? _reflow;
  set reflow(ValueListenable<Map<String, WallRect>>? value) {
    if (identical(value, _reflow)) return;
    if (attached) _reflow?.removeListener(_reflowChanged);
    _reflow = value;
    if (attached) _reflow?.addListener(_reflowChanged);
    _plates?.addListener(markNeedsPaint);
    _reflowChanged();
  }

  void _reflowChanged() {
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  Matrix4? _left, _right;
  set frame(ValueListenable<BravaisFrame> value) {
    if (identical(value, _frame)) return;
    if (attached) _frame.removeListener(_changed);
    _frame = value;
    if (attached) _frame.addListener(_changed);
    _changed();
  }

  set dpr(double value) {
    if (_dpr != value) {
      _dpr = value;
      _changed();
    }
  }

  void _changed() {
    _left = null;
    _right = null;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _changed();
    _frame.addListener(_changed);
    _reflow?.addListener(_reflowChanged);
    _plates?.addListener(markNeedsPaint);
    _reflowChanged();
  }

  @override
  void detach() {
    _frame.removeListener(_changed);
    _reflow?.removeListener(_reflowChanged);
    _plates?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BravaisSeatData) {
      child.parentData = BravaisSeatData();
    }
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth && constraints.hasBoundedHeight);
    size = constraints.biggest;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as BravaisSeatData, slot = data.slot!;
      final rect =
          _reflow?.value[slot.key] ??
          WallRect(slot.x, slot.y, slot.width, slot.height);
      data.rect = rect;
      child.layout(BoxConstraints.tight(Size(rect.width, rect.height)));
      child = data.nextSibling;
    }
  }

  Matrix4 _half(bool left) {
    final cached = left ? _left : _right;
    if (cached != null) return cached;
    final frame = _frame.value,
        tilt = frame.tilt,
        point = left ? frame.left : frame.right,
        camera = snapWallCamera(
          WallCamera(point.x, point.y, frame.scale),
          _dpr,
        ),
        matrix = Matrix4.identity();
    if (tilt.deg.abs() >= .001) {
      matrix
        ..translateByDouble(tilt.pivotX, tilt.pivotY, 0, 1)
        ..rotateZ(tilt.deg * math.pi / 180)
        ..translateByDouble(-tilt.pivotX, -tilt.pivotY, 0, 1);
    }
    matrix
      ..translateByDouble(camera.x, camera.y, 0, 1)
      ..scaleByDouble(camera.scale, camera.scale, 1, 1);
    if (left) {
      _left = matrix;
    } else {
      _right = matrix;
    }
    return matrix;
  }

  bool _onLeft(BravaisSeatData data) =>
      _frame.value.anchorX != null && data.slot!.x < _frame.value.anchorX!;
  Matrix4 _childTransform(BravaisSeatData data) =>
      _half(_onLeft(data)).clone()
        ..translateByDouble(data.rect!.x, data.rect!.y, 0, 1);
  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      context,
      offset,
    ) {
      // Source paints the complete left layer, then the right, preserving world order within each half.
      for (final left in [true, false]) {
        context.pushTransform(needsCompositing, offset, _half(left), (
          context,
          offset,
        ) {
          final plates = _plates;
          if (plates != null) {
            final canvas = context.canvas;
            canvas.save();
            canvas.translate(offset.dx, offset.dy);
            plates.paint(canvas, left, _reflow?.value ?? const {});
            canvas.restore();
          }
          var child = firstChild;
          while (child != null) {
            final data = child.parentData! as BravaisSeatData;
            if (_onLeft(data) == left) {
              context.paintChild(
                child,
                offset + Offset(data.rect!.x, data.rect!.y),
              );
            }
            child = data.nextSibling;
          }
        });
      }
    }, clipBehavior: Clip.hardEdge);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final left in [false, true]) {
      var child = lastChild;
      while (child != null) {
        final target = child, data = target.parentData! as BravaisSeatData;
        if (_onLeft(data) == left &&
            result.addWithPaintTransform(
              transform: _childTransform(data),
              position: position,
              hitTest: (result, transformed) =>
                  target.hitTest(result, position: transformed),
            )) {
          return true;
        }
        child = data.previousSibling;
      }
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_childTransform(child.parentData! as BravaisSeatData));
}

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../rendering/css_numeric.dart';
import '../../../wall/wall_opacity.dart';
import '../../../wall/wall_paint_boundary.dart';
import '../../../wall/wall_overflow_hit_test.dart';
import 'bravais_album_motion.dart';

// Retain the original static layout/legacy transform below the CSS individual translate/rotate/scale. Word translations use that word's own computed em size; opacity stays floating point.
class BravaisAlbumEntranceLayer extends StatelessWidget {
  const BravaisAlbumEntranceLayer({
    super.key,
    required this.motion,
    required this.child,
    this.em = 1,
    this.origin = Alignment.center,
  });
  final ValueListenable<BravaisAlbumMotion> motion;
  final Widget child;
  final double em;
  final Alignment origin;
  @override
  Widget build(BuildContext context) => WallOpacity(
    opacity: _AlbumOpacity(motion),
    child: _AlbumTransform(
      motion: motion,
      em: em,
      origin: origin,
      child: WallPaintBoundary(child: child),
    ),
  );
}

class _AlbumOpacity implements ValueListenable<double> {
  const _AlbumOpacity(this.motion);
  final ValueListenable<BravaisAlbumMotion> motion;
  @override
  double get value => motion.value.opacity;
  @override
  void addListener(VoidCallback listener) => motion.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => motion.removeListener(listener);
}

class _AlbumTransform extends SingleChildRenderObjectWidget {
  const _AlbumTransform({
    required this.motion,
    required this.em,
    required this.origin,
    super.child,
  });
  final ValueListenable<BravaisAlbumMotion> motion;
  final double em;
  final Alignment origin;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBravaisAlbumEntrance(motion, em, origin);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBravaisAlbumEntrance renderObject,
  ) => renderObject.update(motion, em, origin);
}

class RenderBravaisAlbumEntrance extends RenderProxyBox
    with WallOverflowHitTest {
  RenderBravaisAlbumEntrance(
    this._motion,
    this._em, [
    this._origin = Alignment.center,
  ]);
  ValueListenable<BravaisAlbumMotion> _motion;
  double _em;
  Alignment _origin;
  final _matrix = Matrix4.identity(), _layer = LayerHandle<TransformLayer>();
  BravaisAlbumMotion? _previous;
  ((double, double, double, double, double), Size, double, Alignment)?
  _geometry;
  void update(
    ValueListenable<BravaisAlbumMotion> value,
    double em, [
    Alignment origin = Alignment.center,
  ]) {
    if (!identical(value, _motion)) {
      if (attached) _motion.removeListener(_changed);
      _motion = value;
      if (attached) _motion.addListener(_changed);
    }
    _em = em;
    _origin = origin;
    _changed();
    markNeedsPaint();
  }

  Matrix4 get transform {
    final frame = _motion.value,
        key = (
          (frame.x, frame.y, frame.rotate, frame.scaleX, frame.scaleY),
          size,
          _em,
          _origin,
        );
    if (_geometry == key) return _matrix;
    _geometry = key;
    final pivot = _origin.alongSize(size);
    _matrix
      ..setIdentity()
      ..translateByDouble(
        pivot.dx + cssFloat32(frame.x * _em),
        pivot.dy + cssFloat32(frame.y * _em),
        0,
        1,
      )
      ..rotateZ(frame.rotate * math.pi / 180)
      ..scaleByDouble(frame.scaleX, frame.scaleY, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
    return _matrix;
  }

  void _changed() {
    final next = _motion.value, old = _previous;
    _previous = next;
    if (old?.visible != next.visible) markNeedsSemanticsUpdate();
    if (old == null ||
        (old.x, old.y, old.rotate, old.scaleX, old.scaleY, old.visible) !=
            (
              next.x,
              next.y,
              next.rotate,
              next.scaleX,
              next.scaleY,
              next.visible,
            )) {
      markNeedsPaint();
    }
  }

  @override
  Rect get paintBounds => _motion.value.visible && hasSize
      ? MatrixUtils.transformRect(
          transform,
          child?.paintBounds ?? (Offset.zero & size),
        )
      : Rect.zero;
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion.addListener(_changed);
  }

  @override
  void detach() {
    _motion.removeListener(_changed);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || !_motion.value.visible) {
      _layer.layer = null;
      return;
    }
    _layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      super.paint,
      oldLayer: _layer.layer,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _motion.value.visible &&
      result.addWithPaintTransform(
        transform: transform,
        position: position,
        hitTest: (result, position) =>
            super.hitTest(result, position: position),
      );
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(this.transform);
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_motion.value.visible) super.visitChildrenForSemantics(visitor);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

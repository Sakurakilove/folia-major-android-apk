import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../visualizer/motion/bezier.dart';

// Original controls reveal uses the wall's shared clock and retained child. No widget rebuilds per frame; the subscription ends at 380ms.
class BravaisFocusReveal extends ChangeNotifier {
  BravaisFocusReveal({
    required this.frames,
    required this.nowMs,
    required this.startedAt,
    this.reducedMotion = false,
  });
  final Listenable frames;
  double Function() nowMs;
  final double startedAt;
  bool reducedMotion, _attached = false, _closed = false;
  double? _progress;
  double get progress => _progress ??= _sample();
  double _sample() => reducedMotion
      ? 1
      : cssBezier(
          .42,
          0,
          .58,
          1,
          ((nowMs() - startedAt - 140) / 240).clamp(0.0, 1.0),
        );
  bool get _running => progress < 1;
  void setReduced(bool value) {
    if (value == reducedMotion) return;
    reducedMotion = value;
    _progress = _sample();
    _sync();
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _progress = _sample();
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  void _sync() {
    final wanted = !_closed && hasListeners && _running;
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_frame);
    } else {
      frames.removeListener(_frame);
    }
  }

  void _frame() {
    _progress = _sample();
    _sync();
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _sync();
    super.dispose();
  }
}

class BravaisFocusRevealLayer extends SingleChildRenderObjectWidget {
  const BravaisFocusRevealLayer({super.key, required this.reveal, super.child});
  final BravaisFocusReveal reveal;
  @override
  RenderBravaisFocusReveal createRenderObject(BuildContext context) =>
      RenderBravaisFocusReveal(reveal);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisFocusReveal renderObject,
  ) => renderObject.reveal = reveal;
}

class RenderBravaisFocusReveal extends RenderProxyBox {
  RenderBravaisFocusReveal(this._reveal);
  BravaisFocusReveal _reveal;
  final _transformLayer = LayerHandle<TransformLayer>(),
      _opacityLayer = LayerHandle<ColorFilterLayer>();
  set reveal(BravaisFocusReveal value) {
    if (identical(value, _reveal)) return;
    if (attached) _reveal.removeListener(_changed);
    _reveal = value;
    if (attached) _reveal.addListener(_changed);
    _changed();
  }

  void _changed() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _reveal.addListener(_changed);
  }

  @override
  void detach() {
    _reveal.removeListener(_changed);
    super.detach();
  }

  Matrix4 get transform =>
      Matrix4.translationValues(0, 12 * (1 - _reveal.progress), 0);
  @override
  void paint(PaintingContext context, Offset offset) {
    final p = _reveal.progress;
    if (p == 0 || child == null) return;
    if (p == 1) {
      _transformLayer.layer = null;
      _opacityLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) {
        _opacityLayer.layer = context.pushColorFilter(
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
            p,
            0,
          ]),
          super.paint,
          oldLayer: _opacityLayer.layer,
        );
      },
      oldLayer: _transformLayer.layer,
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
    _transformLayer.layer = null;
    _opacityLayer.layer = null;
    super.dispose();
  }
}

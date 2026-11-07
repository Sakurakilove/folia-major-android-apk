import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Keep CSS's floating compositor alpha while retaining text and icon display lists across opacity frames.
class WallOpacity extends SingleChildRenderObjectWidget {
  const WallOpacity({super.key, required this.opacity, super.child});
  final ValueListenable<double> opacity;
  @override
  RenderWallOpacity createRenderObject(BuildContext context) =>
      RenderWallOpacity(opacity);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderWallOpacity renderObject,
  ) => renderObject.opacity = opacity;
}

class RenderWallOpacity extends RenderProxyBox {
  RenderWallOpacity(this._opacity);
  ValueListenable<double> _opacity;
  final _layer = LayerHandle<ColorFilterLayer>();
  set opacity(ValueListenable<double> next) {
    if (identical(next, _opacity)) return;
    if (attached) _opacity.removeListener(markNeedsPaint);
    _opacity = next;
    if (attached) _opacity.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;
  @override
  Rect get paintBounds => child?.paintBounds ?? (Offset.zero & size);
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _opacity.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _opacity.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final alpha = _opacity.value;
    if (alpha >= 1) {
      _layer.layer = null;
      super.paint(context, offset);
    } else if (alpha <= 0) {
      _layer.layer = null;
    } else {
      _layer.layer = context.pushColorFilter(
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
        oldLayer: _layer.layer,
      );
    }
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

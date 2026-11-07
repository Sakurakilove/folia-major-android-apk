import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Retained wall faces include CSS shadows beyond their layout box. Flutter's default boundary reports only its own size, which is not the original poster's paint extent.
class WallPaintBoundary extends SingleChildRenderObjectWidget {
  const WallPaintBoundary({super.key, super.child});
  @override
  RenderWallPaintBoundary createRenderObject(BuildContext context) =>
      RenderWallPaintBoundary();
}

class RenderWallPaintBoundary extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;
  @override
  Rect get paintBounds => child?.paintBounds ?? (Offset.zero & size);
}

class WallFaceInset extends SingleChildRenderObjectWidget {
  const WallFaceInset({super.key, required this.inset, super.child});
  final double inset;
  @override
  RenderWallFaceInset createRenderObject(BuildContext context) =>
      RenderWallFaceInset(inset);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderWallFaceInset renderObject,
  ) => renderObject.padding = EdgeInsets.all(inset);
}

class RenderWallFaceInset extends RenderPadding {
  RenderWallFaceInset(double inset) : super(padding: EdgeInsets.all(inset));
  @override
  Rect get paintBounds {
    final content = child;
    if (content == null) return Offset.zero & size;
    return content.paintBounds
        .shift((content.parentData! as BoxParentData).offset)
        .expandToInclude(Offset.zero & size);
  }
}

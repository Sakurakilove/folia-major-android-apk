part of 'bravais_viewport.dart';

// Retained native poster children share two camera transforms. Panning repaints/repositions layers without rebuilding or laying out the wall.
class BravaisViewport extends MultiChildRenderObjectWidget {
  const BravaisViewport({
    super.key,
    required this.frame,
    required this.dpr,
    this.reflow,
    this.plates,
    super.children,
  });
  final ValueListenable<BravaisFrame> frame;
  final double dpr;
  final BravaisPlatePainter? plates;
  final ValueListenable<Map<String, WallRect>>? reflow;
  @override
  RenderBravaisViewport createRenderObject(BuildContext context) =>
      RenderBravaisViewport(frame, dpr)
        ..reflow = reflow
        ..plates = plates;
  @override
  void updateRenderObject(
    BuildContext context,
    RenderBravaisViewport renderObject,
  ) {
    renderObject
      ..frame = frame
      ..dpr = dpr
      ..reflow = reflow
      ..plates = plates;
  }
}

class BravaisSeat extends ParentDataWidget<BravaisSeatData> {
  const BravaisSeat({super.key, required this.slot, required super.child});
  final WallSlot slot;
  @override
  Type get debugTypicalAncestorWidgetClass => BravaisViewport;
  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as BravaisSeatData, old = data.slot;
    data.slot = slot;
    if (old?.width != slot.width || old?.height != slot.height) {
      renderObject.parent?.markNeedsLayout();
    } else if (old?.x != slot.x || old?.y != slot.y) {
      renderObject.parent?.markNeedsLayout();
      renderObject.parent?.markNeedsSemanticsUpdate();
    }
  }
}

class BravaisSeatData extends ContainerBoxParentData<RenderBox> {
  WallSlot? slot;
  WallRect? rect;
}

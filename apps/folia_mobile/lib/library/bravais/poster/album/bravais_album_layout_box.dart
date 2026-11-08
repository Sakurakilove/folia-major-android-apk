part of 'bravais_album_layout.dart';

// The stage may shrink to zero content height, retaining its 18px padding while the fixed-ratio cover overflows. CSS flex centering truncates signed half LayoutUnits toward zero.
class _AlbumLayoutParentData extends ContainerBoxParentData<RenderBox> {}

class RenderBravaisAlbumLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _AlbumLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _AlbumLayoutParentData> {
  final _clip = LayerHandle<ClipRectLayer>();
  List<RenderBox> _paintOrder = const [];
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _AlbumLayoutParentData) {
      child.parentData = _AlbumLayoutParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
  @override
  void performLayout() {
    size = constraints.biggest;
    final top = firstChild!,
        cover = childAfter(top)!,
        scrap = childAfter(cover)!,
        title = childAfter(scrap)!,
        bottom = childAfter(title)!;
    // top and bottom have z-index:2; stage/title retain their ordinary DOM order.
    _paintOrder = [cover, scrap, title, top, bottom];
    void content(RenderBox child, double width) => child.layout(
      BoxConstraints.tightFor(width: math.max(0, width)),
      parentUsesSize: true,
    );
    content(top, size.width - 60);
    content(title, size.width - 80);
    content(bottom, size.width - 80);
    final topHeight = top.size.height + 18,
        bottomHeight = bottom.size.height + 40,
        stageHeight = math.max(
          18.0,
          size.height - topHeight - 28 - title.size.height - 20 - bottomHeight,
        ),
        side = math.min(
          cssLayoutPercent(size.width, 56),
          cssLayoutPercent(size.height, 33),
        );
    cover.layout(BoxConstraints.tight(Size.square(side)), parentUsesSize: true);
    scrap.layout(
      BoxConstraints(
        maxWidth: math.max(0, size.width - 30),
        maxHeight: cssLayoutPercent(stageHeight, 70),
      ),
      parentUsesSize: true,
    );
    void place(RenderBox child, Offset position) =>
        (child.parentData! as _AlbumLayoutParentData).offset = position;
    place(top, const Offset(20, 18));
    place(
      cover,
      Offset(58, topHeight + 18 + cssLayoutUnit((stageHeight - 18 - side) / 2)),
    );
    place(scrap, Offset(size.width - 30 - scrap.size.width, topHeight + 24));
    final titleY = topHeight + stageHeight + 28;
    place(title, Offset(40, titleY));
    place(bottom, Offset(40, titleY + title.size.height + 20));
  }

  @override
  Rect get paintBounds {
    if (!hasSize) return Rect.zero;
    var bounds = Offset.zero & size;
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as _AlbumLayoutParentData;
      bounds = bounds.expandToInclude(child.paintBounds.shift(data.offset));
      child = data.nextSibling;
    }
    return Rect.fromLTRB(0, bounds.top, size.width, bounds.bottom);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      paintBounds,
      (context, offset) {
        for (final child in _paintOrder) {
          context.paintChild(
            child,
            offset + (child.parentData! as _AlbumLayoutParentData).offset,
          );
        }
      },
      clipBehavior: Clip.hardEdge,
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (position.dx < 0 || position.dx >= size.width) return false;
    for (final child in _paintOrder.reversed) {
      if (result.addWithPaintOffset(
        offset: (child.parentData! as _AlbumLayoutParentData).offset,
        position: position,
        hitTest: (result, position) =>
            child.hitTest(result, position: position),
      )) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

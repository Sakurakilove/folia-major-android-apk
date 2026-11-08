part of 'bravais_album_cover.dart';

// The positioned tape does not affect figure size. Report every child's transformed overflow so native retained layers never crop the tape, its overshoot or the original 12px hard shadow.
class _AlbumCoverParentData extends ContainerBoxParentData<RenderBox> {}

class RenderBravaisAlbumCoverBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _AlbumCoverParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _AlbumCoverParentData> {
  RenderBravaisAlbumCoverBox(
    this._tapeX,
    Color ink,
    Color block,
    this._hasImage,
    this._onLayout,
  ) {
    _ink.color = ink;
    _block.color = block;
  }
  double _tapeX;
  bool _hasImage;
  VoidCallback? _onLayout;
  bool get imageReady =>
      !_hasImage || (firstChild as RenderWallArtworkImage).image != null;
  Color get ink => _ink.color;
  final _ink = Paint(), _block = Paint();
  void update(
    double tapeX,
    Color ink,
    Color block,
    bool hasImage,
    VoidCallback? onLayout,
  ) {
    _hasImage = hasImage;
    if (_onLayout != onLayout) {
      _onLayout = onLayout;
      markNeedsLayout();
    }
    if (_tapeX != tapeX) {
      _tapeX = tapeX;
      markNeedsLayout();
    }
    if (_ink.color != ink || _block.color != block) {
      _ink.color = ink;
      _block.color = block;
      markNeedsPaint();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _AlbumCoverParentData) {
      child.parentData = _AlbumCoverParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
  @override
  void performLayout() {
    size = constraints.biggest;
    final image = firstChild!, tape = childAfter(image)!;
    image.layout(BoxConstraints.tight(size));
    (image.parentData! as _AlbumCoverParentData).offset = Offset.zero;
    final tapeWidth = size.width * .3;
    tape.layout(BoxConstraints.tight(Size(tapeWidth, 24)));
    (tape.parentData! as _AlbumCoverParentData).offset = Offset(
      size.width * _tapeX - tapeWidth / 2,
      -12,
    );
    _onLayout?.call();
  }

  @override
  Rect get paintBounds {
    if (!hasSize) return Rect.zero;
    var bounds = (Offset.zero & size).expandToInclude(
      const Offset(12, 12) & size,
    );
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as _AlbumCoverParentData;
      bounds = bounds.expandToInclude(child.paintBounds.shift(data.offset));
      child = data.nextSibling;
    }
    return bounds;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas
      ..drawRect((offset + const Offset(12, 12)) & size, _ink)
      ..drawRect(offset & size, _block);
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;
}

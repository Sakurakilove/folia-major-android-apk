part of 'bravais_tile_view.dart';

// Match the source outer-seat measurement: incoming face transforms are deliberately excluded; only keyboard focus pop and the actual face inset alter the target cover rectangle.
extension _BravaisTileCover on _BravaisTileViewState {
  RenderBox? get _coverBox {
    if (!mounted) return null;
    final render = _coverKey.currentContext?.findRenderObject();
    return render is RenderBox && render.attached && render.hasSize
        ? render
        : null;
  }

  BravaisCoverQuad? _measureCover() {
    final box = _coverBox,
        shown = _motion.face.value.payload,
        look = widget.look.showing(
          shown,
          current: shown.item?.key == widget.nowPlayingKey,
          hovered: _hover || widget.look.hovered,
        );
    if (box == null) return null;
    final quad = measureBravaisCover(box);
    if (quad == null) return null;
    final inset = look.faceInset;
    return bravaisTileCoverQuad(
      tile: quad,
      tileSize: box.size,
      face: Rect.fromLTWH(
        inset,
        inset,
        math.max(0, box.size.width - inset * 2),
        math.max(0, box.size.height - inset * 2),
      ),
      hasBackgroundImage: true,
      popX: look.focused ? look.scaleX : 1,
      popY: look.focused ? look.scaleY : 1,
    );
  }

  void _registerCover() {
    _releaseCover = widget.resources.coverTiles?.register(
      widget.slot.key,
      BravaisCoverTileBinding(
        connected: () => _coverBox != null,
        tile: BravaisCoverReturnTile(
          measure: _measureCover,
          cardKey: () {
            if (_coverBox == null) return null;
            final face = _motion.face.value.payload, item = face.item;
            return face.kind != BravaisTileKind.heading &&
                    item?.kind != BravaisItemKind.track
                ? item?.key
                : null;
          },
          finishFiniteEntrances: () {
            void finish(RenderObject render) {
              if (render is RenderBravaisCard) {
                render.finishFiniteFaceAnimations();
              } else {
                render.visitChildren(finish);
              }
            }

            final box = _coverBox;
            if (box != null) finish(box);
          },
        ),
      ),
    );
  }
}

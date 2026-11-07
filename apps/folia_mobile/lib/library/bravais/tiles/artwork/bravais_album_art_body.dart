part of 'bravais_album_artwork.dart';

// Body lifetime follows the original art span: an unavailable placement removes it; a retained span changes mode without restarting unrelated tracks.
class _AlbumArtBody extends StatefulWidget {
  const _AlbumArtBody({
    required this.source,
    required this.placement,
    required this.artwork,
  });
  final BravaisAlbumArtwork source;
  final BravaisArtPlacement placement;
  final WallPosterArtwork artwork;
  @override
  State<_AlbumArtBody> createState() => _AlbumArtBodyState();
}

class _AlbumArtBodyState extends State<_AlbumArtBody> {
  late final BravaisAlbumArtMotion _motion;
  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _motion = BravaisAlbumArtMotion(
      frames: s.frames,
      nowMs: s.nowMs,
      mode: s.art.mode,
      placement: widget.placement,
      accent: s.accent,
      block: s.block,
      restored: s.restored,
    );
  }

  @override
  void didUpdateWidget(_AlbumArtBody old) {
    super.didUpdateWidget(old);
    final s = widget.source;
    _motion.rebind(s.frames, s.nowMs);
    _motion.update(
      mode: s.art.mode,
      placement: widget.placement,
      accent: s.accent,
      block: s.block,
      restored: s.restored,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    return BravaisArtworkLayer(
      program: s.program,
      store: s.store,
      style: _motion,
      cover: s.art.url,
      sizePx:
          (s.art.mode == BravaisArtMode.mosaic
              ? bravaisAlbumMosaicPx
              : math.max(s.rect.width, s.rect.height) * 2.75) *
          s.pixelScale,
      mosaic: s.art.mode == BravaisArtMode.mosaic,
      active: s.active,
      artwork: widget.artwork,
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}

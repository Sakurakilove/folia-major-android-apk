import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../artwork/wall_artwork_store.dart';
import '../../../../artwork/wall_poster_artwork.dart';
import '../../../wall/wall_types.dart';
import '../../bravais_album_art.dart';
import '../bravais_item.dart';
import 'bravais_album_art_motion.dart';
import 'bravais_art_program.dart';
import 'bravais_artwork_layer.dart';
import 'bravais_artwork_samples.dart';

part 'bravais_album_art_body.dart';

// Album-wall artwork preloads while detail spots are pending, as the original two hooks do. The native body only appears once both placement and its URL exist.
class BravaisAlbumArtwork extends StatefulWidget {
  const BravaisAlbumArtwork({
    super.key,
    required this.art,
    required this.itemKey,
    required this.rect,
    required this.column,
    required this.row,
    required this.pixelScale,
    required this.accent,
    required this.block,
    required this.samples,
    required this.store,
    required this.program,
    required this.frames,
    required this.nowMs,
    required this.restored,
    this.active = true,
    this.showArtwork = true,
  });
  final BravaisCoverArt art;
  final String itemKey;
  final WallRect rect;
  final int column, row;
  final double pixelScale;
  final Color accent, block;
  final BravaisArtworkSamples samples;
  final WallArtworkStore store;
  final BravaisArtProgram program;
  final Listenable frames;
  final double Function() nowMs;
  final bool restored, active, showArtwork;
  @override
  State<BravaisAlbumArtwork> createState() => _BravaisAlbumArtworkState();
}

class _BravaisAlbumArtworkState extends State<BravaisAlbumArtwork> {
  ValueListenable<List<WallPoint>?>? _spots;
  WallPosterArtwork? _artwork;
  bool _tickerEnabled = true;
  bool get _active => widget.active && _tickerEnabled;
  double get _sizePx =>
      (widget.art.mode == BravaisArtMode.mosaic
          ? bravaisAlbumMosaicPx
          : math.max(widget.rect.width, widget.rect.height) * 2.75) *
      widget.pixelScale;
  @override
  void initState() {
    super.initState();
    _bindSpots();
  }

  void _bindSpots() {
    _spots =
        widget.art.mode == BravaisArtMode.shard &&
            widget.store.policy.identity(widget.art.url).isNotEmpty
        ? widget.samples.spots(widget.art.url)
        : null;
    _spots?.addListener(_changed);
    if (_spots != null) widget.samples.requestSpots(widget.art.url);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _createArtwork() {
    _artwork = WallPosterArtwork(
      widget.store,
      widget.art.url,
      _sizePx,
      active: _active,
    )..addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_artwork == null) _createArtwork();
    _artwork!.setActive(_active);
  }

  @override
  void didUpdateWidget(BravaisAlbumArtwork old) {
    super.didUpdateWidget(old);
    if (old.art.url != widget.art.url ||
        old.art.mode != widget.art.mode ||
        !identical(old.samples, widget.samples) ||
        !identical(old.store, widget.store)) {
      _spots?.removeListener(_changed);
      _bindSpots();
    }
    if (!identical(old.store, widget.store)) {
      _artwork?.removeListener(_changed);
      _artwork?.dispose();
      _createArtwork();
    } else {
      _artwork?.setActive(_active);
      _artwork?.update(widget.art.url, _sizePx);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showArtwork || _artwork == null || _artwork!.value.isEmpty) {
      return const SizedBox.shrink();
    }
    final spots = _spots?.value;
    final placement = widget.art.mode == BravaisArtMode.mosaic
        ? bravaisMosaicPlacement(widget.rect, widget.column, widget.row)
        : spots == null
        ? null
        : bravaisShardPlacement(spots, widget.itemKey, widget.rect);
    return placement == null
        ? const SizedBox.shrink()
        : _AlbumArtBody(
            source: widget,
            placement: placement,
            artwork: _artwork!,
          );
  }

  @override
  void dispose() {
    _spots?.removeListener(_changed);
    _artwork?.removeListener(_changed);
    _artwork?.dispose();
    super.dispose();
  }
}

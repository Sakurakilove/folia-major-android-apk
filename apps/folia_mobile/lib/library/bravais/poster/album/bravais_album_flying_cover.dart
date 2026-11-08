import 'package:flutter/widgets.dart';

import '../bravais_album_composition.dart';
import 'bravais_album_cover.dart';
import 'bravais_album_cover_flight.dart';

// The stage prepares the controller before building the new layer. Its actual mounted figure owns unmount cleanup; do not abort a return merely because a model changed before the render tree detached.
class BravaisAlbumFlyingCover extends StatefulWidget {
  const BravaisAlbumFlyingCover({
    super.key,
    required this.controller,
    required this.posterSize,
    required this.composition,
    required this.provider,
    this.ink = const Color(0xff141210),
    this.block = const Color(0xff22305f),
  });
  final BravaisAlbumCoverFlight controller;
  final Size posterSize;
  final BravaisAlbumComposition composition;
  final ImageProvider<String>? provider;
  final Color ink, block;
  @override
  State<BravaisAlbumFlyingCover> createState() =>
      _BravaisAlbumFlyingCoverState();
}

class _BravaisAlbumFlyingCoverState extends State<BravaisAlbumFlyingCover> {
  @override
  void didUpdateWidget(BravaisAlbumFlyingCover old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) old.controller.dispose();
  }

  @override
  Widget build(BuildContext context) => BravaisAlbumCover(
    posterSize: widget.posterSize,
    composition: widget.composition,
    entrance: widget.controller.entrance,
    anchor: widget.controller.anchor,
    onLayout: widget.controller.didLayout,
    provider: widget.provider,
    ink: widget.ink,
    block: widget.block,
  );

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }
}

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../artwork/wall_artwork_image.dart';
import '../../../../rendering/css_numeric.dart';
import '../../../wall/wall_box_shadows.dart';
import '../bravais_album_composition.dart';
import 'bravais_album_entrance.dart';
import 'bravais_album_entrance_layer.dart';
import 'bravais_album_motion.dart';

part 'bravais_album_cover_box.dart';

// Original unscaled figure: keep CSS individual entrance outside legacy rotation and the tape's own independent animation. The anchor measures the actual rotated figure for cover flight.
class BravaisAlbumCover extends StatelessWidget {
  const BravaisAlbumCover({
    super.key,
    required this.posterSize,
    required this.composition,
    required this.entrance,
    required this.provider,
    this.anchor,
    this.onLayout,
    this.ink = const Color(0xff141210),
    this.block = const Color(0xff22305f),
  });
  final Size posterSize;
  final BravaisAlbumComposition composition;
  final BravaisAlbumEntrance entrance;
  final ImageProvider<String>? provider;
  final GlobalKey? anchor;
  final VoidCallback? onLayout;
  final Color ink, block;

  @override
  Widget build(BuildContext context) {
    final side = math.min(
      cssLayoutPercent(posterSize.width, 56),
      cssLayoutPercent(posterSize.height, 33),
    );
    return SizedBox.square(
      dimension: side,
      child: BravaisAlbumEntranceLayer(
        motion: entrance.signal(BravaisAlbumPart.cover),
        child: Transform.rotate(
          angle: composition.coverDeg * math.pi / 180,
          child: _AlbumCoverBox(
            key: anchor,
            onLayout: onLayout,
            hasImage: provider != null,
            tapeX: composition.tape.x,
            ink: ink,
            block: block,
            image: WallArtworkImage(provider: provider),
            tape: BravaisAlbumEntranceLayer(
              motion: entrance.signal(BravaisAlbumPart.tape),
              child: Transform.rotate(
                angle: composition.tape.deg * math.pi / 180,
                child: const WallBoxShadows(
                  shadows: AlwaysStoppedAnimation([
                    WallBoxShadow(
                      Color.from(alpha: .18, red: 0, green: 0, blue: 0),
                      offset: Offset(0, 1),
                      blur: 2,
                    ),
                  ]),
                  child: ColoredBox(
                    color: Color.from(
                      alpha: .8,
                      red: 214 / 255,
                      green: 212 / 255,
                      blue: 204 / 255,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumCoverBox extends MultiChildRenderObjectWidget {
  _AlbumCoverBox({
    super.key,
    required this.tapeX,
    required this.ink,
    required this.block,
    required this.hasImage,
    required this.onLayout,
    required Widget image,
    required Widget tape,
  }) : super(children: [image, tape]);
  final double tapeX;
  final Color ink, block;
  final bool hasImage;
  final VoidCallback? onLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBravaisAlbumCoverBox(tapeX, ink, block, hasImage, onLayout);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBravaisAlbumCoverBox renderObject,
  ) => renderObject.update(tapeX, ink, block, hasImage, onLayout);
}

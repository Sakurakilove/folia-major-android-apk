import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../artwork/wall_poster_artwork.dart';
import '../../../wall/wall_slots.dart';
import '../../../wall/wall_types.dart';
import '../artwork/bravais_album_artwork.dart';
import '../artwork/bravais_artist_artwork.dart';
import '../bravais_card_copy.dart';
import '../bravais_card_look.dart';
import '../bravais_card_marks.dart';
import '../bravais_item.dart';
import '../bravais_tile_motion.dart';
import '../focus/bravais_focus_actions.dart';
import '../focus/bravais_focus_body.dart';
import 'bravais_card_resources.dart';
import 'bravais_card_skin.dart';
import 'bravais_card_surface.dart';

part 'bravais_card_artwork.dart';

// The actual original card combines shared material, full-resolution artwork, marks and expanded actions. Wall position/flip ownership stays outside this content layer.
class BravaisCardContent extends StatefulWidget {
  const BravaisCardContent({
    super.key,
    required this.slotKey,
    required this.look,
    required this.rect,
    required this.pixelScale,
    required this.viewportWidth,
    required this.resources,
    required this.actions,
    required this.queued,
    required this.entersLattice,
    this.flight,
    this.reducedMotion = false,
    this.active = true,
    this.managingHidden = false,
    this.loading = false,
  });
  final String slotKey;
  final BravaisCardLook look;
  final WallRect rect;
  final double pixelScale, viewportWidth;
  final BravaisCardResources resources;
  final BravaisCardActions actions;
  final BravaisTileMotion<dynamic>? flight;
  final bool queued,
      entersLattice,
      reducedMotion,
      active,
      managingHidden,
      loading;
  @override
  State<BravaisCardContent> createState() => _BravaisCardContentState();
}

class _BravaisCardContentState extends State<BravaisCardContent> {
  WallPosterArtwork? _cover;
  bool _tickerEnabled = true;
  bool get _active => widget.active && _tickerEnabled;
  double get _size =>
      math.max(widget.rect.width, widget.rect.height) * widget.pixelScale;
  void _createCover() => _cover = WallPosterArtwork(
    widget.resources.store,
    widget.look.face.item?.coverUrl,
    _size,
    active: _active,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_cover == null) _createCover();
    _cover!.setActive(_active);
  }

  @override
  void didUpdateWidget(BravaisCardContent old) {
    super.didUpdateWidget(old);
    if (!identical(old.resources.store, widget.resources.store)) {
      _cover?.dispose();
      _createCover();
    } else {
      _cover?.setActive(_active);
      _cover?.update(widget.look.face.item?.coverUrl, _size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget,
        r = w.resources,
        look = w.look,
        p = look.palette,
        item = look.face.item,
        heading = look.face.kind == BravaisTileKind.heading,
        art = !look.face.seeThrough && !look.isExpanded ? item?.coverArt : null;
    Widget expanded(Widget glint) => BravaisFocusBody(
      slotKey: w.slotKey,
      item: item!,
      queued: w.queued,
      current: look.current,
      titleWidth: w.rect.width,
      viewportWidth: w.viewportWidth,
      actions: w.actions,
      typography: r.typography,
      strings: r.strings,
      ink: p.ink,
      accent: p.accent,
      frames: r.frames,
      nowMs: r.nowMs,
      isPlaying: r.isPlaying,
      entersLattice: w.entersLattice,
      reducedMotion: w.reducedMotion,
      glint: glint,
    );
    return BravaisCardSkin(
      look: look,
      frames: r.frames,
      nowMs: r.nowMs,
      flight: w.flight,
      reducedMotion: w.reducedMotion,
      active: _active,
      loading: w.loading,
      mosaic: art?.mode == BravaisArtMode.mosaic,
      cover: item == null || art?.mode == BravaisArtMode.mosaic
          ? null
          : WallPosterImage(
              artwork: _cover!,
              fallback: CustomPaint(painter: BravaisCoverFallback(item.key)),
            ),
      artwork: _cardArtwork(w, _active),
      badge: item == null
          ? null
          : BravaisCardBadge(
              item: item,
              current: !heading && look.current,
              ink: p.ink,
              accent: p.accent,
              background: p.background,
              shade: p.shade,
              typography: r.typography,
            ),
      copy: item == null
          ? null
          : BravaisCardCopy(
              item: item,
              targetWidth: w.rect.width,
              viewportWidth: w.viewportWidth,
              typography: r.typography,
              ink: p.ink,
              heading: heading,
              shadows: art?.mode != BravaisArtMode.mosaic
                  ? null
                  : [
                      Shadow(
                        color: p.shade.withValues(alpha: .6),
                        offset: const Offset(0, 1),
                        blurRadius: (1 - .5) / .57735,
                      ),
                      Shadow(
                        color: p.shade.withValues(alpha: .45),
                        blurRadius: (7 - .5) / .57735,
                      ),
                    ],
            ),
      expandedBody: look.isExpanded ? expanded : null,
      marks: item == null || (!item.hideable && !item.selected)
          ? null
          : BravaisCardMarks(
              item: item,
              managingHidden: w.managingHidden,
              strings: r.strings,
              ink: p.ink,
              background: p.background,
              accent: p.accent,
              frames: r.frames,
              nowMs: r.nowMs,
              reducedMotion: w.reducedMotion,
              toggleHidden: w.actions.toggleHidden == null
                  ? null
                  : () => w.actions.toggleHidden!(w.slotKey),
            ),
    );
  }

  @override
  void dispose() {
    _cover?.dispose();
    super.dispose();
  }
}

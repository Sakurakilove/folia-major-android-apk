import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../../wall/wall_paint_boundary.dart';
import '../bravais_viewport.dart';
import 'bravais_animated_face.dart';
import 'bravais_card_look.dart';
import 'bravais_item.dart';
import 'bravais_tile_input.dart';
import 'bravais_tile_motion.dart';
import 'bravais_tile_types.dart';
import 'focus/bravais_focus_actions.dart';
import 'skin/bravais_card_content.dart';
import 'skin/bravais_card_resources.dart';
import 'skin/bravais_card_layer.dart';
import 'skin/bravais_poster_card_surface.dart';
import '../cover/bravais_cover_tiles.dart';
import '../cover/bravais_cover_flights.dart';
import '../cover/bravais_cover_quad.dart';

part 'bravais_tile_cover.dart';

// The retained original tile host: fixed outer seat/hover target, animated face, source face commits, full card content and discrete CSS stacking priority.
class BravaisTileView extends StatefulWidget {
  const BravaisTileView({
    super.key,
    required this.slot,
    required this.rect,
    required this.look,
    required this.resources,
    required this.actions,
    required this.pointerHistory,
    required this.consumeDrag,
    required this.noteAlbumSource,
    required this.pixelScale,
    required this.viewportWidth,
    required this.queued,
    required this.entersLattice,
    this.nowPlayingKey,
    this.step,
    this.entrance,
    this.reducedMotion = false,
    this.reducedTransitions = false,
    this.managingHidden = false,
    this.active = true,
    this.loading = false,
    this.posterTint = const Color(0x00000000),
  });
  final WallSlot slot;
  final WallRect rect;
  final BravaisCardLook look;
  final BravaisCardResources resources;
  final BravaisCardActions actions;
  final BravaisPointerHistory pointerHistory;
  final bool Function() consumeDrag;
  final void Function(BuildContext tile, BravaisItem item) noteAlbumSource;
  final double pixelScale, viewportWidth;
  final Color posterTint;
  final String? nowPlayingKey;
  final BravaisFlipStep? step;
  final BravaisEntrance? entrance;
  final bool queued,
      entersLattice,
      reducedMotion,
      reducedTransitions,
      managingHidden,
      active,
      loading;
  @override
  State<BravaisTileView> createState() => _BravaisTileViewState();
}

class _BravaisTileViewState extends State<BravaisTileView> {
  late final BravaisTileMotion<BravaisCardFace> _motion;
  final _coverKey = GlobalKey();
  VoidCallback? _releaseCover;
  bool _hover = false, _tickerEnabled = true;
  double _now() => widget.resources.nowMs();
  BravaisTileFace<BravaisCardFace> get _target =>
      BravaisTileFace(widget.look.face.key, widget.look.face);
  @override
  void initState() {
    super.initState();
    _motion = BravaisTileMotion(
      frames: widget.resources.frames,
      nowMs: _now,
      initial: _target,
      rect: widget.rect,
      entrance: widget.entrance,
    );
    _motion.setActive(widget.active);
    _registerCover();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _motion.setActive(widget.active && _tickerEnabled);
  }

  @override
  void didUpdateWidget(BravaisTileView old) {
    super.didUpdateWidget(old);
    if (old.slot.key != widget.slot.key ||
        old.resources.coverTiles != widget.resources.coverTiles) {
      _releaseCover?.call();
      _registerCover();
    }
    _motion.rebindFrames(widget.resources.frames);
    _motion.setActive(widget.active && _tickerEnabled);
    _motion.setTarget(
      _target,
      step: widget.step,
      reducedMotion: widget.reducedTransitions,
    );
    _motion.setEntrance(widget.entrance, widget.rect);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _motion.face,
    builder: (context, shown, _) {
      final w = widget,
          face = shown.payload,
          look = w.look.showing(
            face,
            current: face.item != null && face.item!.key == w.nowPlayingKey,
            hovered: _hover || w.look.hovered,
          );
      return BravaisSeat(
        slot: w.slot,
        zIndex: look.isExpanded
            ? 20
            : look.focused
            ? 4
            : look.hovered
            ? 3
            : 0,
        child: BravaisTileInput(
          key: _coverKey,
          slotKey: w.slot.key,
          face: face,
          expanded: look.isExpanded,
          actions: w.actions,
          pointerHistory: w.pointerHistory,
          consumeDrag: w.consumeDrag,
          noteAlbumSource: (context, item) {
            w.resources.coverTiles?.note(w.slot.key, item.key, item.coverUrl);
            w.noteAlbumSource(context, item);
          },
          onHover: (value) {
            if (mounted && _hover != value) setState(() => _hover = value);
          },
          child: BravaisPosterCardSurface(
            look: look,
            tint: w.posterTint,
            frames: w.resources.frames,
            nowMs: w.resources.nowMs,
            active: w.active,
            child: BravaisFaceLayer(
              motion: _motion,
              child: WallPaintBoundary(
                child: WallFaceInset(
                  inset: look.faceInset,
                  child: BravaisCardContent(
                    slotKey: w.slot.key,
                    look: look,
                    rect: w.rect,
                    pixelScale: w.pixelScale,
                    viewportWidth: w.viewportWidth,
                    resources: w.resources,
                    actions: w.actions,
                    queued: w.queued,
                    entersLattice: w.entersLattice,
                    flight: _motion,
                    reducedMotion: w.reducedMotion,
                    active: w.active,
                    managingHidden: w.managingHidden,
                    loading: w.loading,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  @override
  void dispose() {
    _releaseCover?.call();
    _motion.dispose();
    super.dispose();
  }
}

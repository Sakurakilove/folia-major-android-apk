import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_frame.dart';
import '../bravais_plate_painter.dart';
import '../bravais_viewport.dart';
import '../display/bravais_display.dart';
import '../shape/bravais_wall_shape.dart';
import '../tiles/bravais_card_look.dart';
import '../tiles/bravais_card_palette.dart';
import '../tiles/bravais_item.dart';
import '../tiles/bravais_tile_input.dart';
import '../tiles/bravais_tile_view.dart';
import '../tiles/focus/bravais_focus_actions.dart';
import '../tiles/skin/bravais_card_resources.dart';

// The actual two-half wall assembles retained native seats. Only source display/cull/focus changes build widgets; camera/reflow frames go directly to the viewport.
class BravaisWallView extends StatelessWidget {
  const BravaisWallView({
    super.key,
    required this.slots,
    required this.display,
    required this.frame,
    required this.dpr,
    required this.committedScale,
    required this.viewportWidth,
    required this.resources,
    required this.actions,
    required this.pointerHistory,
    required this.consumeDrag,
    required this.noteAlbumSource,
    required this.palette,
    this.plates,
    this.reflow,
    this.targetReflow = const {},
    this.expandedSlotKey,
    this.focusedSlotKey,
    this.linkedKey,
    this.lightsOut = false,
    this.tinted = false,
    this.stackEdges = true,
    this.posterWall = false,
    this.posterTint = const Color(0x00000000),
    this.reducedMotion = false,
    this.reducedTransitions = false,
    this.managingHidden = false,
    this.entersLattice = false,
    this.active = true,
    this.interactive = true,
    this.android = true,
  });
  final List<WallSlot> slots;
  final BravaisDisplay? display;
  final ValueListenable<BravaisFrame> frame;
  final double dpr, viewportWidth, committedScale;
  final BravaisCardResources resources;
  final BravaisCardActions actions;
  final BravaisPointerHistory pointerHistory;
  final bool Function() consumeDrag;
  final void Function(BuildContext tile, BravaisItem item) noteAlbumSource;
  final BravaisCardPalette palette;
  final bool posterWall;
  final Color posterTint;
  final BravaisPlatePainter? plates;
  final ValueListenable<Map<String, WallRect>>? reflow;
  final Map<String, WallRect> targetReflow;
  final String? expandedSlotKey, focusedSlotKey, linkedKey;
  final bool lightsOut,
      tinted,
      stackEdges,
      reducedMotion,
      reducedTransitions,
      managingHidden,
      entersLattice,
      active,
      interactive,
      android;
  @override
  Widget build(BuildContext context) {
    final data = display,
        shape = data?.shape ?? bravaisBlockShape,
            // Source Android image sizing uses min(DPR,1.5); native painting still uses full DPR.
            pixelScale =
            committedScale * (android ? math.min(dpr, 1.5) : dpr);
    return IgnorePointer(
      ignoring: !interactive,
      child: TickerMode(
        enabled: active,
        child: BravaisViewport(
          frame: frame,
          dpr: dpr,
          reflow: reflow,
          plates: plates,
          children: [
            for (final slot in slots) _tile(slot, data, shape, pixelScale),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    WallSlot slot,
    BravaisDisplay? data,
    BravaisWallShape shape,
    double pixelScale,
  ) {
    final expanded = slot.key == expandedSlotKey,
        face =
            data?.faceAt(slot, expanded: expanded) ??
            const BravaisCardFace(null, BravaisTileKind.wall),
        item = face.item,
        rect =
            targetReflow[slot.key] ??
            WallRect(slot.x, slot.y, slot.width, slot.height);
    return BravaisTileView(
      key: ValueKey('${shape.blockKey(slot.column, slot.row)}:${slot.key}'),
      slot: slot,
      rect: rect,
      look: BravaisCardLook(
        face: face,
        palette: palette,
        width: rect.width,
        height: rect.height,
        expanded: expanded,
        focused: slot.key == focusedSlotKey,
        linked: item != null && item.key == linkedKey,
        lightsOut: lightsOut,
        tinted: tinted,
        stackEdges: stackEdges,
        posterWall: posterWall,
      ),
      resources: resources,
      posterTint: posterTint,
      actions: actions,
      pointerHistory: pointerHistory,
      consumeDrag: consumeDrag,
      noteAlbumSource: noteAlbumSource,
      pixelScale: pixelScale,
      viewportWidth: viewportWidth,
      queued:
          expanded &&
          item != null &&
          (data?.layer.queuedKeys.contains(item.key) ?? false),
      nowPlayingKey: data?.layer.nowPlayingKey,
      entersLattice: entersLattice,
      step: data?.flips[slot.key],
      entrance: data?.entrance,
      reducedMotion: reducedMotion,
      reducedTransitions: reducedTransitions,
      managingHidden: managingHidden,
      active: active,
      loading: data?.layer.isLoading ?? false,
    );
  }
}

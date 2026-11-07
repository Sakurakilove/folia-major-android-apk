import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../wall/wall_box_shadows.dart';
import '../../wall/wall_css_filter.dart';
import 'bravais_card_palette.dart';
import 'bravais_item.dart';

part 'skin/bravais_card_shadows.dart';

// Resolve the original selector precedence once per discrete state. The frame renderer receives numeric/style targets, not a new UI tree per camera frame.
class BravaisCardLook {
  const BravaisCardLook({
    required this.face,
    required this.palette,
    required this.width,
    required this.height,
    this.current = false,
    this.expanded = false,
    this.focused = false,
    this.hovered = false,
    this.linked = false,
    this.lightsOut = false,
    this.tinted = false,
    this.stackEdges = true,
    this.posterWall = false,
  });
  final BravaisCardFace face;
  final BravaisCardPalette palette;
  final double width, height;
  final bool current,
      expanded,
      focused,
      hovered,
      linked,
      lightsOut,
      tinted,
      stackEdges,
      posterWall;
  BravaisCardLook showing(
    BravaisCardFace shown, {
    required bool current,
    required bool hovered,
  }) => BravaisCardLook(
    face: shown,
    palette: palette,
    width: width,
    height: height,
    current: current,
    expanded: expanded,
    focused: focused,
    hovered: hovered,
    linked: linked,
    lightsOut: lightsOut,
    tinted: tinted,
    stackEdges: stackEdges,
    posterWall: posterWall,
  );
  double get faceInset => posterWall && !isExpanded ? 10 : 0;
  double get posterTintOpacity =>
      posterWall &&
          !hovered &&
          !focused &&
          !current &&
          !isExpanded &&
          face.kind != BravaisTileKind.wall &&
          face.kind != BravaisTileKind.window
      ? .3
      : 0;
  bool get isExpanded => expanded && face.item?.kind == BravaisItemKind.track;
  bool get selected => face.item?.selected ?? false;
  bool get dimmed => (face.item?.dimmed ?? false) && !isExpanded;
  bool get stack => face.item?.form == BravaisTileForm.stack;
  bool get exempt => hovered || current || focused || linked || selected;
  bool get portraitRestored => exempt || isExpanded;
  bool get shardRestored => hovered || focused || current;
  bool get _pops =>
      (hovered || focused) &&
      !isExpanded &&
      face.kind != BravaisTileKind.wall &&
      face.kind != BravaisTileKind.window &&
      face.kind != BravaisTileKind.heading;
  // Original inline custom properties are serialized with toFixed(4).
  double _pop(double extent) =>
      double.parse(((extent + 16) / math.max(extent, 1)).toStringAsFixed(4));
  double get scaleX => _pops ? _pop(width) : 1;
  double get scaleY => _pops ? _pop(height) : 1;
  WallCssFilter get filter {
    // This selector has greater specificity than dimmed/unavailable/hover, including heading cards.
    if (posterWall &&
        !isExpanded &&
        face.kind != BravaisTileKind.wall &&
        face.kind != BravaisTileKind.window) {
      return const WallCssFilter([WallFilterOp(WallFilterKind.saturate, .6)]);
    }
    if (dimmed) {
      return const WallCssFilter([WallFilterOp(WallFilterKind.grayscale, 1)]);
    }
    if (face.kind == BravaisTileKind.wall ||
        face.kind == BravaisTileKind.window ||
        isExpanded) {
      return WallCssFilter.none;
    }
    if (face.item?.unavailable ?? false) {
      return const WallCssFilter([
        WallFilterOp(WallFilterKind.grayscale, .85),
        WallFilterOp(WallFilterKind.brightness, .8),
      ]);
    }
    return hovered
        ? const WallCssFilter([
            WallFilterOp(WallFilterKind.saturate, 1.08),
            WallFilterOp(WallFilterKind.brightness, 1.05),
          ])
        : WallCssFilter.none;
  }

  double get tint => tinted && !lightsOut && !exempt && !face.seeThrough
      ? palette.tintOpacity
      : 0;
  double get dim =>
      lightsOut && !exempt && !isExpanded && !face.seeThrough ? .82 : 0;
  double get copyAlpha => lightsOut && !exempt && face.seeThrough ? .28 : 1;
  double get opacity => dimmed ? .35 : 1;
  double get duoOpacity =>
      face.item?.form == BravaisTileForm.portrait &&
          !face.seeThrough &&
          !exempt &&
          !isExpanded
      ? 1
      : 0;
  // CSS's dimmed rule replaces the entire transition list, so transform snaps while entering that state.
  double get transformDuration => dimmed ? 0 : 300;
  double get filterDuration => dimmed ? 200 : 600;
  double get opacityDuration => dimmed ? 200 : 0;
  double get shadowDuration => dimmed
      ? 0
      : stack
      ? 300
      : 600;
}

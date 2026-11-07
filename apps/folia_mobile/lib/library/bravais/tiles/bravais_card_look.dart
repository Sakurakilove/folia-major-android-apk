import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../wall/wall_box_shadows.dart';
import '../../wall/wall_css_filter.dart';
import 'bravais_card_palette.dart';
import 'bravais_item.dart';

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
      stackEdges;
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

  List<WallBoxShadow> get currentShadows => [
    WallBoxShadow(
      palette.shade.withValues(alpha: focused ? .62 : .52),
      spread: 1,
      inset: true,
    ),
    const WallBoxShadow(Color(0x00000000), spread: 3, inset: true),
    WallBoxShadow(
      palette.accent.withValues(
        alpha: palette.accent.a * (focused ? .62 : .46),
      ),
      blur: focused ? 26 : 15,
      spread: focused ? -6 : -7,
      modern: true,
      inset: true,
    ),
  ];

  List<WallBoxShadow> get shadows {
    if (face.kind == BravaisTileKind.wall) {
      return [
        WallBoxShadow(
          palette.ink.withValues(alpha: palette.ink.a * .07),
          spread: 1,
          modern: true,
          inset: true,
        ),
      ];
    }
    if (face.kind == BravaisTileKind.window) {
      return const [];
    }
    final p = palette;
    final ring = <WallBoxShadow>[
      WallBoxShadow(p.focusHairline, spread: 1),
      WallBoxShadow(p.ink, spread: 4),
      WallBoxShadow(p.outerHairline, spread: 5),
    ];
    // Linked/selected selectors replace the entire shadow list, even on an expanded or currently playing card.
    if (!focused && (linked || selected)) return ring;
    final elevation = <WallBoxShadow>[];
    if (stack && stackEdges) {
      final fade = lightsOut && !exempt && face.seeThrough ? .28 : 1.0,
          pageDim = lightsOut && !exempt && !face.seeThrough ? .82 : 0.0;
      Color color(Color base) =>
          p.stackColor(base, tint: tint, dim: pageDim, alpha: fade);
      final retract = hovered || focused;
      elevation.addAll([
        WallBoxShadow(
          color(p.stackNear),
          modern: true,
          offset: retract ? Offset.zero : const Offset(3, 3),
        ),
        WallBoxShadow(
          color(p.stackLine),
          modern: true,
          offset: retract ? Offset.zero : const Offset(3, 3),
          spread: retract ? 0 : 1,
        ),
        WallBoxShadow(
          color(p.stackFar),
          modern: true,
          offset: retract ? Offset.zero : const Offset(6, 6),
        ),
        WallBoxShadow(
          color(p.stackLine),
          modern: true,
          offset: retract ? Offset.zero : const Offset(6, 6),
          spread: retract ? 0 : 1,
        ),
      ]);
    }
    elevation.add(
      isExpanded
          ? WallBoxShadow(
              const Color(0xff000000).withValues(alpha: p.daylight ? .25 : .74),
              offset: const Offset(0, 42),
              blur: 110,
            )
          : WallBoxShadow(
              const Color(0xff000000)
                  .withValues(alpha: focused ? (p.daylight ? .25 : .45) : 0),
              offset: const Offset(0, 12),
              blur: 32,
            ),
    );
    final placeholders = [
      for (final spread in [1.0, 4.0, 5.0])
        WallBoxShadow(const Color(0x00000000), spread: spread),
    ];
    return [...(focused && !current ? ring : placeholders), ...elevation];
  }
}

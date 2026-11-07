import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../wall/wall_box_shadows.dart';
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
  bool get _pops =>
      (hovered || focused) &&
      !isExpanded &&
      face.kind != BravaisTileKind.wall &&
      face.kind != BravaisTileKind.window &&
      face.kind != BravaisTileKind.heading;
  double get scaleX => _pops ? (width + 16) / math.max(width, 1) : 1;
  double get scaleY => _pops ? (height + 16) / math.max(height, 1) : 1;
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

  List<WallBoxShadow> get shadows {
    if (face.kind == BravaisTileKind.wall ||
        face.kind == BravaisTileKind.window) {
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
          offset: retract ? Offset.zero : const Offset(3, 3),
        ),
        WallBoxShadow(
          color(p.stackLine),
          offset: retract ? Offset.zero : const Offset(3, 3),
          spread: retract ? 0 : 1,
        ),
        WallBoxShadow(
          color(p.stackFar),
          offset: retract ? Offset.zero : const Offset(6, 6),
        ),
        WallBoxShadow(
          color(p.stackLine),
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
    final placeholders = List.generate(
      3,
      (_) => const WallBoxShadow(Color(0x00000000)),
    );
    return [...(focused && !current ? ring : placeholders), ...elevation];
  }
}

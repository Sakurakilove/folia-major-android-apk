part of '../bravais_card_look.dart';

// The source shadow selectors replace/pad entire lists; keep them separate from the numeric card appearance targets.
extension BravaisCardShadows on BravaisCardLook {
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

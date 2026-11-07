import 'package:flutter/widgets.dart';

import '../../../i18n/folia_strings.dart';
import '../../../rendering/folia_icons.dart';
import '../../../visualizer/motion/css_transition.dart';
import '../../wall/wall_typography.dart';
import 'bravais_control.dart';
import 'bravais_item.dart';

part 'bravais_card_eye.dart';

// These are card-local source marks, not new floating controls. Hidden editing is the only mode that renders the eye button.
class BravaisCardBadge extends StatelessWidget {
  const BravaisCardBadge({
    super.key,
    required this.item,
    required this.current,
    required this.ink,
    required this.accent,
    required this.background,
    required this.shade,
    required this.typography,
  });
  final BravaisItem item;
  final bool current;
  final Color ink, accent, background, shade;
  final WallTypography typography;
  @override
  Widget build(BuildContext context) {
    final special = item.special,
        color = special == null ? (current ? accent : ink) : background;
    return Positioned(
      top: 14,
      left: 14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: special == null
              ? shade.withValues(alpha: current ? .78 : .62)
              : accent,
          boxShadow: special == null
              ? null
              : [
                  BoxShadow(
                    color: shade.withValues(alpha: .34),
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (special != null) ...[
                FoliaIcon(
                  special.icon,
                  color: color,
                  size: 12,
                  strokeWidth: 2.6,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                item.badge,
                textScaler: TextScaler.noScaling,
                style: typography.style(
                  11,
                  color: color,
                  weight: 800,
                  tracking: .12,
                  tabular: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BravaisCardMarks extends StatelessWidget {
  const BravaisCardMarks({
    super.key,
    required this.item,
    required this.managingHidden,
    required this.strings,
    required this.ink,
    required this.background,
    required this.accent,
    required this.frames,
    required this.nowMs,
    this.toggleHidden,
    this.reducedMotion = false,
  });
  final BravaisItem item;
  final bool managingHidden;
  final FoliaStrings strings;
  final Color ink, background, accent;
  final VoidCallback? toggleHidden;
  final bool reducedMotion;
  final Listenable frames;
  final double Function() nowMs;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (managingHidden && item.hideable && toggleHidden != null)
        Positioned(
          top: 10,
          right: 10,
          child: _HideEye(
            item: item,
            strings: strings,
            accent: accent,
            onTap: toggleHidden!,
            reducedMotion: reducedMotion,
            frames: frames,
            nowMs: nowMs,
          ),
        ),
      if (item.selected)
        Positioned(
          top: 10,
          right: 10,
          child: IgnorePointer(
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: ink),
              child: FoliaIcon(
                'Check',
                color: background,
                size: 15,
                strokeWidth: 3,
              ),
            ),
          ),
        ),
    ],
  );
}

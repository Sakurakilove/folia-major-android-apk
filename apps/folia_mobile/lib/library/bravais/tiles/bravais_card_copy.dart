import 'package:flutter/widgets.dart';

import '../../../rendering/css_text.dart';
import '../../wall/wall_title.dart';
import '../../wall/wall_typography.dart';
import 'bravais_item.dart';

// Compact and heading copy retain the original bottom anchor, typography, subtitle exclusion and destination-width title fit.
class BravaisCardCopy extends StatelessWidget {
  const BravaisCardCopy({
    super.key,
    required this.item,
    required this.targetWidth,
    required this.viewportWidth,
    required this.typography,
    required this.ink,
    this.heading = false,
    this.shadows,
  });
  final BravaisItem item;
  final double targetWidth, viewportWidth;
  final WallTypography typography;
  final Color ink;
  final bool heading;
  final List<Shadow>? shadows;
  @override
  Widget build(BuildContext context) {
    final portrait = item.form == BravaisTileForm.portrait && !heading,
        titleSize =
            (viewportWidth * .02).clamp(22.0, 36.0) * (portrait ? 1.3 : 1);
    return Positioned(
      left: 17,
      right: 17,
      bottom: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!heading || item.title.isNotEmpty)
            WallTitle(
              title: item.title,
              style: typography
                  .style(
                    titleSize,
                    color: ink,
                    weight: 700,
                    height: .96,
                    tracking: portrait ? -.05 : -.045,
                  )
                  .copyWith(shadows: shadows),
              targetWidth: targetWidth - 34,
              fontsEpoch: typography.fontsEpoch,
              maxLines: heading ? 2 : 3,
              locale: typography.locale,
              direction: typography.direction,
            ),
          if (!portrait && item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              cssNormalText(item.subtitle),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textDirection: typography.direction,
              textScaler: TextScaler.noScaling,
              style: typography
                  .style(
                    13,
                    color: ink.withValues(alpha: ink.a * .78),
                    weight: 650,
                  )
                  .copyWith(shadows: shadows),
            ),
          ],
        ],
      ),
    );
  }
}

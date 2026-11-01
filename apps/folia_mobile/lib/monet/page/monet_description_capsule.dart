import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../rendering/folia_typography.dart';

// Original bordered, blurred theme capsule; the 1px border participates in CSS box sizing.
class MonetDescriptionCapsule extends StatelessWidget {
  const MonetDescriptionCapsule({
    super.key,
    required this.label,
    required this.primary,
    required this.background,
    required this.accent,
    required this.typography,
  });
  final String label;
  final Color primary, background, accent;
  final FoliaTypography typography;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: primary.withValues(alpha: .16)),
              color: background.withValues(alpha: .18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      style: typography
                          .withHeight(16 / 12)
                          .style(12, color: primary.withValues(alpha: .9)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

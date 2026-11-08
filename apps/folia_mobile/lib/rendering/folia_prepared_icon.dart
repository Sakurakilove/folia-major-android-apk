part of 'folia_icons.dart';

// Page preparation supplies the real parsed Lucide paths before handoff. Render the first visible frame synchronously with the same painter; no blank FutureBuilder frame or frame-time asset IO.
class FoliaPreparedIcon extends StatelessWidget {
  const FoliaPreparedIcon(
    this.data, {
    super.key,
    required this.color,
    this.size = 24,
    this.strokeWidth = 2,
    this.absoluteStrokeWidth = false,
    this.filled = false,
    this.semanticLabel,
  });
  final FoliaIconData data;
  final Color color;
  final double size, strokeWidth;
  final bool absoluteStrokeWidth, filled;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(
          data,
          color,
          size,
          strokeWidth,
          absoluteStrokeWidth,
          filled,
        ),
      ),
    ),
  );
}

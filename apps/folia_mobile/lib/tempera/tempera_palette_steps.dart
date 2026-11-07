part of 'tempera_palette.dart';

// Preserve source rounding before each luminance check and stable sorting (including reversing equal-ranked cover colors toward darker ink).
String _matchLuminance(String color, String target) {
  final channels = visualizerColorChannels(color);
  if (channels == null) return target;
  final current = temperaColorLuminance(color),
      wanted = temperaColorLuminance(target);
  if (current <= .5) return target;
  final gain = wanted / current,
      r = _round(math.min(255, channels.r * gain)),
      g = _round(math.min(255, channels.g * gain)),
      b = _round(math.min(255, channels.b * gain)),
      scaled = 'rgb($r, $g, $b)';
  return (temperaColorLuminance(scaled) - wanted).abs() > 1.5 ? target : scaled;
}

List<String> _toneLadder(
  String paper,
  String ink, [
  String? tintA,
  String? tintB,
]) => List.unmodifiable(
  List.generate(4, (index) {
    final base = mixVisualizerColors(paper, ink, temperaToneStops[index]),
        tint = index == 0 || index == 2
            ? tintA
            : index == 1
            ? tintB
            : null;
    return tint == null || tint.isEmpty
        ? base
        : _matchLuminance(mixVisualizerColors(base, tint, .3), base);
  }),
);
List<String> _gradientRamp(String paper, String ink, List<String> sources) {
  final ranked = sources
      .map(jsTrim)
      .where((s) => s.isNotEmpty)
      .indexed
      .toList();
  ranked.sort((a, b) {
    final difference = temperaColorLuminance(a.$2)
        .compareTo(temperaColorLuminance(b.$2));
    return difference != 0 ? difference : a.$1.compareTo(b.$1);
  });
  final ordered =
      (temperaColorLuminance(ink) < temperaColorLuminance(paper)
              ? ranked.reversed
              : ranked)
          .map((p) => p.$2)
          .toList();
  return List.unmodifiable(
    List.generate(4, (index) {
      final rung = mixVisualizerColors(paper, ink, temperaToneStops[index]),
          hue = ordered.isEmpty ? null : ordered[index % ordered.length];
      return hue == null
          ? rung
          : _matchLuminance(mixVisualizerColors(rung, hue, .78), rung);
    }),
  );
}

String _readable(String paper, String color) {
  final lum = temperaColorLuminance(paper);
  if ((temperaColorLuminance(color) - lum).abs() >= 88) return color;
  final away = lum < 128 ? '#ffffff' : '#101010';
  for (var step = 1; step <= 5; step++) {
    final pushed = mixVisualizerColors(color, away, step * .16);
    if ((temperaColorLuminance(pushed) - lum).abs() >= 88) return pushed;
  }
  return mixVisualizerColors(color, away, .8);
}

List<String>? _textGradient(String paper, List<String> sources) {
  final usable = sources.map(jsTrim).where((s) => s.isNotEmpty).toList();
  if (usable.isEmpty) return null;
  return List.unmodifiable(
    List.generate(4, (i) => _readable(paper, usable[i % usable.length])),
  );
}

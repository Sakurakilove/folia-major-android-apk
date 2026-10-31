import 'dart:math' as math;

// Port of visualizer/monet/monetLyricMotion.ts; keep the absolute-time envelopes unchanged.
double clampProgress(double value) => value.clamp(0.0, 1.0);

double resolveMonetGlow(double time, double start, double end, double lineEnd) {
  if (time <= start) return 0;
  final rise = math.max(0.001, end - start) * 1.18;
  final peak = start + rise;
  final tail = math.max(lineEnd, end + 1.05);
  if (time <= peak) {
    final p = clampProgress((time - start) / rise);
    return p * p * (3 - 2 * p);
  }
  final remaining =
      1 - clampProgress((time - peak) / math.max(0.18, tail - peak));
  return remaining * remaining * (3 - 2 * remaining);
}

double resolveMonetFillWidth(
  double time,
  double start,
  double end,
  List<double> offsets,
) {
  final width = offsets.last;
  if (time <= start) return 0;
  if (time >= end) return width;
  final index =
      clampProgress((time - start) / math.max(0.001, end - start)) *
      (offsets.length - 1);
  final whole = index.floor();
  final a = offsets[whole];
  final b = offsets[math.min(whole + 1, offsets.length - 1)];
  return a + (b - a) * (index - whole);
}

({double opacity, double scale, double blur}) resolveMonetTone(
  String status,
  int offset,
) {
  if (status == 'active') return (opacity: 1, scale: 1, blur: 0);
  final distance = math.max(offset.abs(), 1);
  final waiting = status == 'waiting';
  return (
    opacity: waiting
        ? math.max(0.36, 0.72 - (distance - 1) * 0.18)
        : math.max(0.28, 0.52 - (distance - 1) * 0.12),
    scale: math.max(0.68, 0.72 * math.pow(0.9, distance - 1)),
    blur: waiting
        ? distance == 1
              ? 0.7
              : 1.8 + (distance - 2) * 0.8
        : 1.1 + (distance - 1) * 0.7,
  );
}

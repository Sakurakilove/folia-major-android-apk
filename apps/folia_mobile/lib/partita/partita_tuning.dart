import 'dart:math' as math;

// Preserve original Partita stored fields, finite 0..180 bounds and min/max swap; defaults are the baseline exported settings.
class PartitaTuning {
  const PartitaTuning(
    this.showGuideLines,
    this.useSemanticLayout,
    this.staggerMin,
    this.staggerMax,
  );
  final bool showGuideLines, useSemanticLayout;
  final double staggerMin, staggerMax;
  factory PartitaTuning.resolve(
    Map<String, dynamic> stored,
    Map<String, dynamic> defaults,
  ) {
    double read(String key) {
      final fallback = (defaults[key] as num).toDouble(),
          value = (stored[key] as num?)?.toDouble() ?? fallback;
      return value.isFinite ? value.clamp(0, 180) : fallback;
    }

    final a = read('staggerMin'), b = read('staggerMax');
    return PartitaTuning(
      stored['showGuideLines'] as bool? ?? defaults['showGuideLines'] as bool,
      stored['useSemanticLayout'] as bool? ??
          defaults['useSemanticLayout'] as bool,
      math.min(a, b),
      math.max(a, b),
    );
  }
  Map<String, dynamic> toJson() => {
    'showGuideLines': showGuideLines,
    'useSemanticLayout': useSemanticLayout,
    'staggerMin': staggerMin,
    'staggerMax': staggerMax,
  };
}

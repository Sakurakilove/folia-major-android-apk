// Original classic_tuning persisted fields and finite 0..2 bounds; defaults come from original exported settings.
class ClassicTuning {
  const ClassicTuning({
    required this.enableWordRotation,
    required this.breathingFloatMultiplier,
    required this.useLegacyLayout,
    required this.wordSpacing,
  });
  final bool enableWordRotation, useLegacyLayout;
  final double breathingFloatMultiplier, wordSpacing;
  factory ClassicTuning.resolve(
    Map<String, dynamic> stored,
    Map<String, dynamic> defaults,
  ) {
    double finite(String name, double fallback) {
      final value = (stored[name] as num?)?.toDouble() ?? fallback;
      return value.isFinite ? value.clamp(0, 2) : fallback;
    }

    return ClassicTuning(
      enableWordRotation:
          stored['enableWordRotation'] as bool? ??
          defaults['enableWordRotation'] as bool,
      breathingFloatMultiplier: finite(
        'breathingFloatMultiplier',
        (defaults['breathingFloatMultiplier'] as num).toDouble(),
      ),
      useLegacyLayout:
          stored['useLegacyLayout'] as bool? ??
          defaults['useLegacyLayout'] as bool,
      wordSpacing: finite(
        'wordSpacing',
        (defaults['wordSpacing'] as num?)?.toDouble() ?? .7,
      ),
    );
  }
  Map<String, dynamic> toJson() => {
    'enableWordRotation': enableWordRotation,
    'breathingFloatMultiplier': breathingFloatMultiplier,
    'useLegacyLayout': useLegacyLayout,
    'wordSpacing': wordSpacing,
  };
}

// Port of monet/tuning.ts; defaults are supplied from the exported original DEFAULT_MONET_TUNING.
class MonetTuning {
  const MonetTuning({
    required this.keywordColoringEnabled,
    required this.showDescription,
    required this.showAudioVisualization,
    required this.audioStyle,
    required this.fontScale,
    required this.portraitSource,
    required this.portraitOffsetX,
    required this.portraitStyle,
    required this.showPortraitDragHanger,
  });
  factory MonetTuning.resolve(
    Map<String, dynamic> parsed,
    Map<String, dynamic> defaults,
  ) {
    final scale = (parsed['fontScale'] as num? ?? defaults['fontScale'] as num)
        .toDouble();
    final offset = parsed['portraitOffsetX'];
    return MonetTuning(
      keywordColoringEnabled:
          parsed['keywordColoringEnabled'] as bool? ??
          defaults['keywordColoringEnabled'] as bool,
      showDescription:
          parsed['showDescription'] as bool? ??
          defaults['showDescription'] as bool,
      showAudioVisualization:
          parsed['showAudioVisualization'] as bool? ??
          defaults['showAudioVisualization'] as bool,
      audioStyle: parsed['audioStyle'] == 'line'
          ? 'line'
          : defaults['audioStyle'] as String,
      fontScale: scale.isFinite
          ? scale.clamp(.7, 1.5)
          : (defaults['fontScale'] as num).toDouble(),
      portraitSource: parsed['portraitSource'] == 'custom'
          ? 'custom'
          : defaults['portraitSource'] as String,
      portraitOffsetX: offset is num
          ? offset.toDouble().clamp(-150.0, 0.0)
          : (defaults['portraitOffsetX'] as num? ?? 0).toDouble(),
      portraitStyle: parsed['portraitStyle'] == 'rectangular'
          ? 'rectangular'
          : defaults['portraitStyle'] as String,
      showPortraitDragHanger:
          parsed['showPortraitDragHanger'] as bool? ??
          defaults['showPortraitDragHanger'] as bool,
    );
  }
  final bool keywordColoringEnabled,
      showDescription,
      showAudioVisualization,
      showPortraitDragHanger;
  final String audioStyle, portraitSource, portraitStyle;
  final double fontScale, portraitOffsetX;
  Map<String, dynamic> toJson() => {
    'keywordColoringEnabled': keywordColoringEnabled,
    'showDescription': showDescription,
    'showAudioVisualization': showAudioVisualization,
    'audioStyle': audioStyle,
    'fontScale': fontScale,
    'portraitSource': portraitSource,
    'portraitOffsetX': portraitOffsetX,
    'portraitStyle': portraitStyle,
    'showPortraitDragHanger': showPortraitDragHanger,
  };
  MonetTuning withPortraitOffset(double value) => MonetTuning(
    keywordColoringEnabled: keywordColoringEnabled,
    showDescription: showDescription,
    showAudioVisualization: showAudioVisualization,
    audioStyle: audioStyle,
    fontScale: fontScale,
    portraitSource: portraitSource,
    portraitOffsetX: value,
    portraitStyle: portraitStyle,
    showPortraitDragHanger: showPortraitDragHanger,
  );
}

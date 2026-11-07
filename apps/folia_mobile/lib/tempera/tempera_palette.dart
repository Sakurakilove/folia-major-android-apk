import 'dart:math' as math;

import '../rendering/js_text.dart';
import '../rendering/js_number.dart';
import '../rendering/visualizer_color_mix.dart';
import '../theme/folia_theme.dart';

part 'tempera_palette_steps.dart';

// Original mono/duo/gradient palette, shared with the original artist/album posters. These are discrete theme/cover calculations, never per-frame parsing or sorting.
class TemperaPalette {
  const TemperaPalette({
    required this.paper,
    required this.ink,
    required this.blockA,
    required this.blockB,
    required this.blockC,
    required this.accent,
    required this.line,
    required this.shadow,
    required this.tones,
    this.gradient,
    this.textGradient,
  });
  final String paper, ink, blockA, blockB, blockC, accent, line, shadow;
  final List<String> tones;
  final List<String>? gradient, textGradient;
  String get tone1 => tones[0];
  String get tone2 => tones[1];
  String get tone3 => tones[2];
  String get tone4 => tones[3];
  Map<String, dynamic> toJson() => {
    'paper': paper,
    'ink': ink,
    'blockA': blockA,
    'blockB': blockB,
    'blockC': blockC,
    'accent': accent,
    'line': line,
    'shadow': shadow,
    'tone1': tone1,
    'tone2': tone2,
    'tone3': tone3,
    'tone4': tone4,
    'gradient': gradient,
    'textGradient': textGradient,
  };
}

const temperaToneStops = [.12, .3, .52, .72];
double temperaColorLuminance(String color) {
  final c = visualizerColorChannels(color);
  return c == null ? 128 : c.r * .2126 + c.g * .7152 + c.b * .0722;
}

int _round(double value) => jsRound(value).toInt();
String _gray(String color, String fallback) {
  if (visualizerColorChannels(color) == null) return fallback;
  final value = _round(temperaColorLuminance(color));
  return 'rgb($value, $value, $value)';
}

String _ensureInk(String paper, String ink) {
  final lum = temperaColorLuminance(paper);
  if ((temperaColorLuminance(ink) - lum).abs() >= 96) return ink;
  final target = lum < 128 ? '#f4f4f2' : '#141414',
      tinted = mixVisualizerColors(target, ink, .14);
  return (temperaColorLuminance(tinted) - lum).abs() >= 96 ? tinted : target;
}

TemperaPalette resolveTemperaPalette(
  FoliaTheme theme,
  String colorMode, [
  List<String> coverColors = const [],
]) {
  final mono = colorMode == 'mono',
      paper = mono
          ? _gray(theme.backgroundColor, '#111111')
          : theme.backgroundColor;
  var ink = mono
      ? _gray(theme.primaryColor, '#f5f5f5')
      : _ensureInk(paper, theme.primaryColor);
  if (mono) {
    final paperGray = visualizerColorChannels(paper)?.r ?? 128,
        inkGray = visualizerColorChannels(ink)?.r ?? 128;
    if ((inkGray - paperGray).abs() < 96) {
      ink = paperGray < 128 ? '#f2f2f2' : '#141414';
    }
    return TemperaPalette(
      paper: paper,
      ink: ink,
      blockA: mixVisualizerColors(paper, ink, .08),
      blockB: mixVisualizerColors(paper, ink, .18),
      blockC: mixVisualizerColors(paper, ink, .34),
      accent: mixVisualizerColors(paper, ink, .85),
      line: visualizerColorWithAlpha(mixVisualizerColors(paper, ink, .55), .55),
      shadow: visualizerColorWithAlpha(
        mixVisualizerColors(paper, ink, .75),
        .35,
      ),
      tones: _toneLadder(paper, ink),
    );
  }
  if (colorMode == 'gradient') {
    final themeHues = [
          theme.accentColor,
          theme.secondaryColor,
          theme.primaryColor,
          ink,
        ],
        hues = coverColors.length >= 2
            ? [
                for (var i = 0; i < math.min(4, coverColors.length); i++)
                  mixVisualizerColors(
                    coverColors[i],
                    themeHues[i % themeHues.length],
                    .32,
                  ),
              ]
            : themeHues,
        ramp = _gradientRamp(paper, ink, hues);
    return TemperaPalette(
      paper: paper,
      ink: ink,
      blockA: ramp[0],
      blockB: ramp[1],
      blockC: ramp[2],
      accent: theme.accentColor,
      line: visualizerColorWithAlpha(mixVisualizerColors(paper, ink, .6), .5),
      shadow: visualizerColorWithAlpha(
        mixVisualizerColors(paper, ink, .8),
        .32,
      ),
      tones: ramp,
      gradient: ramp,
      textGradient: _textGradient(paper, hues),
    );
  }
  return TemperaPalette(
    paper: paper,
    ink: ink,
    blockA: mixVisualizerColors(paper, theme.accentColor, .55),
    blockB: mixVisualizerColors(paper, theme.secondaryColor, .6),
    blockC: mixVisualizerColors(paper, ink, .78),
    accent: theme.accentColor,
    line: visualizerColorWithAlpha(mixVisualizerColors(paper, ink, .6), .5),
    shadow: visualizerColorWithAlpha(mixVisualizerColors(paper, ink, .8), .32),
    tones: _toneLadder(paper, ink, theme.accentColor, theme.secondaryColor),
  );
}

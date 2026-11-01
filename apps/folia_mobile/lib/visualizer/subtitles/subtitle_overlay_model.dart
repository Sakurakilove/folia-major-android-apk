import '../../lyrics/lyric_types.dart';
import '../../lyrics/subtitle_tracks.dart';

// Shared by every original style using VisualizerSubtitleOverlay; marker filtering and recent-line fallback stay identical.
class SubtitleOverlayContent {
  const SubtitleOverlayContent(
    this.shouldRenderOverlay,
    this.subtitleText,
    this.tracks,
    this.upcomingLines,
  );
  final bool shouldRenderOverlay;
  final String? subtitleText;
  final List<SubtitleTrack> tracks;
  final List<LyricLine> upcomingLines;
}

final _readable = RegExp(r'[\p{L}\p{N}]', unicode: true);
SubtitleOverlayContent resolveSubtitleOverlayContent({
  required bool showText,
  required LyricLine? activeLine,
  required LyricLine? recentCompletedLine,
  required List<LyricLine> nextLines,
  bool hideTranslationSubtitle = false,
  bool showSubtitleTranslation = true,
  SubtitleContentMode? subtitleContentMode,
}) {
  if (!showText || hideTranslationSubtitle) {
    return const SubtitleOverlayContent(false, null, [], []);
  }
  final mode = resolveSubtitleContentMode(
    subtitleContentMode,
    showSubtitleTranslation,
  );
  var tracks = <SubtitleTrack>[];
  for (final line in [activeLine, recentCompletedLine]) {
    tracks = resolveLyricSubtitleTracks(
      line,
      mode,
      isReadable: _readable.hasMatch,
    );
    if (tracks.isNotEmpty) break;
  }
  final text = tracks.isNotEmpty
      ? tracks.map((track) => track.text).join(' / ')
      : null;
  return SubtitleOverlayContent(
    true,
    text,
    tracks,
    text != null || activeLine == null
        ? []
        : nextLines.where((line) => _readable.hasMatch(line.text)).toList(),
  );
}

({String translationFontSize, String upcomingFontSize})
resolveSubtitleFontSizes([double lyricsFontScale = 1]) {
  final scale = lyricsFontScale.isFinite && lyricsFontScale > 0
      ? lyricsFontScale
      : 1.0;
  String clamp(double min, double preferred, double max) =>
      'clamp(${(min * scale).toStringAsFixed(3)}rem, ${(preferred * scale).toStringAsFixed(3)}vw, ${(max * scale).toStringAsFixed(3)}rem)';
  return (
    translationFontSize: clamp(1.125, 2.6, 1.25),
    upcomingFontSize: clamp(.875, 2, 1),
  );
}

String scaleSubtitleFontSize(
  String fontSize,
  double scale, [
  double factor = 1,
]) => fontSize.replaceAllMapped(
  RegExp(r'(-?\d*\.?\d+)(rem|vw|px)'),
  (match) =>
      '${(double.parse(match[1]!) * scale * factor).toStringAsFixed(3)}${match[2]}',
);

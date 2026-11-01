import 'lyric_types.dart';

// Same source order and fallback semantics as alternateText.ts and subtitleTrackStyle.ts.
enum SubtitleContentMode { translation, romanization, both, none }

enum SubtitleTrackRole { romanization, translation }

class SubtitleTrack {
  const SubtitleTrack(this.role, this.text);
  final SubtitleTrackRole role;
  final String text;
  Map<String, dynamic> toJson() => {'role': role.name, 'text': text};
}

const secondaryTrackSizeFactor = .88;
const secondaryTrackOpacity = .82;
const secondaryTrackFontWeightFallback = 400;
const secondaryTrackGapEm = .25;

String? _text(LyricLine line, SubtitleTrackRole role) {
  final direct =
      (role == SubtitleTrackRole.translation
              ? line.translation
              : line.romanization)
          ?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  for (final item in line.alternateTexts) {
    if (item.role == role.name && item.text.trim().isNotEmpty) {
      return item.text.trim();
    }
  }
  return null;
}

SubtitleContentMode resolveSingleTrackSubtitleMode(SubtitleContentMode mode) =>
    mode == SubtitleContentMode.both ? SubtitleContentMode.translation : mode;

String? resolveLyricAlternateText(LyricLine? line, SubtitleContentMode mode) {
  final single = resolveSingleTrackSubtitleMode(mode);
  if (line == null || single == SubtitleContentMode.none) return null;
  return _text(line, SubtitleTrackRole.values.byName(single.name));
}

List<SubtitleTrack> resolveLyricSubtitleTracks(
  LyricLine? line,
  SubtitleContentMode mode, {
  bool Function(String)? isReadable,
}) {
  if (line == null || mode == SubtitleContentMode.none) return const [];
  final roles = mode == SubtitleContentMode.both
      ? SubtitleTrackRole.values
      : [SubtitleTrackRole.values.byName(mode.name)];
  final tracks = <SubtitleTrack>[];
  for (final role in roles) {
    final text = _text(line, role);
    if (text == null || (isReadable != null && !isReadable(text))) continue;
    if (tracks.any((track) => track.text == text)) continue;
    tracks.add(SubtitleTrack(role, text));
  }
  return List.unmodifiable(tracks);
}

SubtitleContentMode resolveSubtitleContentMode(
  SubtitleContentMode? mode, [
  bool legacy = true,
]) =>
    mode ??
    (legacy ? SubtitleContentMode.translation : SubtitleContentMode.none);

SubtitleContentMode cycleSubtitleContentMode(SubtitleContentMode mode) =>
    switch (mode) {
      SubtitleContentMode.translation => SubtitleContentMode.romanization,
      SubtitleContentMode.romanization => SubtitleContentMode.both,
      _ => SubtitleContentMode.translation,
    };

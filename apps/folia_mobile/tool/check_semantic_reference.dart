import 'package:folia_mobile/lyrics/lyric_types.dart';
import 'package:folia_mobile/lyrics/semantic_layout.dart';
import 'package:folia_mobile/lyrics/word_segmentation.dart';
import 'package:folia_mobile/lyrics/subtitle_tracks.dart';
import 'package:folia_mobile/visualizer/subtitles/subtitle_overlay_model.dart';

// The oracle supplies plain ICU boundaries, isolating saved splits/sticky layout from the still-pending native engine integration.
void checkSemanticReference(
  Map data,
  void Function(dynamic, dynamic, String) same,
) {
  for (final row in data['overlayCases']) {
    final input = row['input'];
    LyricLine? read(dynamic line) => line == null
        ? null
        : LyricLine.fromJson(Map<String, dynamic>.from(line));
    final content = resolveSubtitleOverlayContent(
      showText: input['showText'],
      activeLine: read(input['activeLine']),
      recentCompletedLine: read(input['recentCompletedLine']),
      nextLines: [for (final line in input['nextLines']) read(line)!],
      subtitleContentMode: SubtitleContentMode.values.byName(
        input['subtitleContentMode'],
      ),
    );
    same(
      {
        'shouldRenderOverlay': content.shouldRenderOverlay,
        'subtitleText': content.subtitleText,
        'subtitleTracks': content.tracks
            .map((track) => track.toJson())
            .toList(),
        'upcomingLines': content.upcomingLines
            .map((line) => line.text)
            .toList(),
      },
      row['expected'],
      'shared.overlay',
    );
  }
  for (final row in data['subtitleSizeCases']) {
    final sizes = resolveSubtitleFontSizes((row['scale'] as num).toDouble());
    same(
      {
        'translationFontSize': sizes.translationFontSize,
        'upcomingFontSize': sizes.upcomingFontSize,
      },
      row['expected'],
      'shared.sizes',
    );
  }
  for (final row in data['semanticCases']) {
    final line = LyricLine.fromJson(Map<String, dynamic>.from(row['line']));
    List<LyricWordSegment> plain(String text) => [
      for (final part in row['plain'])
        LyricWordSegment(part['segment'], part['index'], part['isWordLike']),
    ];
    same(
      segmentLyricWords(line, plain).map((s) => s.toJson()).toList(),
      row['segments'],
      'segmentation',
    );
    same(wordSegmentationKey(line), row['key'], 'segmentation.key');
    same(
      hasWordSegmentationOverride(line),
      row['override'],
      'segmentation.override',
    );
    for (final layout in row['layouts']) {
      final units = buildPostLyricLayoutUnits(
        line,
        segmentPlain: plain,
        semantic: layout['semantic'],
        sticky: layout['sticky'],
      );
      same(
        units.map((u) => u.toJson()).toList(),
        layout['units'],
        'semantic.units',
      );
      same(
        displayWordsFromLayoutUnits(units).map((w) => w.toJson()).toList(),
        layout['displayWords'],
        'semantic.words',
      );
    }
  }
}

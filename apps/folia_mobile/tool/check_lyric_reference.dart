import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:folia_mobile/lyrics/grapheme_timing.dart';
import 'package:folia_mobile/lyrics/lyric_document.dart';
import 'package:folia_mobile/lyrics/render_hints.dart';
import 'package:folia_mobile/lyrics/subtitle_tracks.dart';
import 'package:folia_mobile/monet/monet_lyrics_model.dart';
import 'package:folia_mobile/monet/monet_motion.dart';
import 'package:folia_mobile/monet/rail/monet_rail_layout.dart';
import 'package:folia_mobile/monet/monet_portrait_layers.dart';
import 'package:folia_mobile/rendering/word_coloring.dart';
import 'package:folia_mobile/theme/folia_theme.dart';
import 'package:folia_mobile/theme/font_stacks.dart';

// Minimal differential check against actual baseline functions; synthetic metrics test geometry, not typography.
void same(dynamic actual, dynamic expected, [String path = 'value']) {
  if (actual is num && expected is num) {
    if ((actual - expected).abs() < 1e-9) return;
  } else if (actual is Map && expected is Map) {
    if (actual.length == expected.length &&
        actual.keys.every(expected.containsKey)) {
      for (final key in actual.keys) {
        same(actual[key], expected[key], '$path.$key');
      }
      return;
    }
  } else if (actual is List && expected is List) {
    if (actual.length == expected.length) {
      for (var i = 0; i < actual.length; i++) {
        same(actual[i], expected[i], '$path[$i]');
      }
      return;
    }
  } else if (actual == expected) {
    return;
  }
  throw StateError('$path differs: $actual != $expected');
}

class _SyntheticMeasure implements MonetTextMeasurement {
  double width(String text) => text.characters.length * 11.0;
  @override
  double lineHeight(String text, String font, double fontPx, double fallback) =>
      fallback;
  @override
  int textLineCount(
    String text,
    String font,
    double maxWidth,
    double lineHeight,
  ) => math.max(1, (width(text) / maxWidth).ceil());
  @override
  ({int lineCount, double maxLineWidth}) lyricStats(
    LyricLine line,
    String font,
    double maxWidth,
  ) {
    var count = 1, x = 0.0, widest = 0.0;
    for (final token in buildMonetDisplayTokens(line)) {
      final advance = width(token.text);
      if (x > 0 && x + advance > maxWidth) {
        widest = math.max(widest, x);
        count++;
        x = 0;
      }
      x += advance;
    }
    return (lineCount: count, maxLineWidth: math.max(widest, x));
  }
}

void main() {
  final data = jsonDecode(
    File('test/fixtures/lyric_reference.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final document = LyricDocument.fromJson(
        data['document'] as Map<String, dynamic>,
      ),
      lines = document.lines;
  same(document.toJson(), data['document'], 'normalized metadata round trip');
  same(
    lines
        .map((l) => buildMonetDisplayTokens(l).map((t) => t.toJson()).toList())
        .toList(),
    data['tokens'],
    'tokens',
  );
  same(
    lines
        .map(
          (l) => buildLineGraphemeTimeline(l).map((t) => t.toJson()).toList(),
        )
        .toList(),
    data['timelines'],
    'timelines',
  );
  same(
    lines.map((l) => l.hints.toJson()).toList(),
    data['hints'],
    'render hints',
  );
  for (var i = 0; i < lines.length; i++) {
    final h = lines[i].hints,
        t = getLineTransitionTiming(
          h.rawDuration,
          h.lineTransitionMode,
          h.wordRevealMode,
        );
    same(
      {
        'enterDuration': t.enterDuration,
        'exitDuration': t.exitDuration,
        'linePassHold': t.linePassHold,
      },
      data['transitions'][i],
      'transitions[$i]',
    );
    for (final mode in SubtitleContentMode.values) {
      same(
        resolveMonetSubtitleTracks(
          lines[i],
          mode,
        ).map((t) => t.toJson()).toList(),
        data['subtitles'][i][mode.name],
        'subtitles[$i].${mode.name}',
      );
    }
    same(
      resolveLyricSubtitleTracks(
        lines[i],
        SubtitleContentMode.both,
      ).map((t) => t.toJson()).toList(),
      data['genericSubtitles'][i],
      'generic subtitles[$i]',
    );
  }
  final values = data['inputs'] as Map;
  final inputs = MonetLineLayoutInputs(
    fontPx: (values['fontPx'] as num).toDouble(),
    translationFontPx: (values['translationFontPx'] as num).toDouble(),
    fontStack: values['fontStack'] as String,
    translationFontStack: values['translationFontStack'] as String,
    maxWidthPx: (values['maxWidthPx'] as num).toDouble(),
    subtitleContentMode: SubtitleContentMode.both,
  );
  final measure = _SyntheticMeasure();
  for (var i = 0; i < lines.length; i++) {
    for (final status in ['active', 'waiting', 'passed']) {
      same(
        measureMonetLineLayout(lines[i], status, inputs, measure).toJson(),
        data['layouts'][i][status],
        'layouts[$i].$status',
      );
    }
  }
  List<MonetVisibleLineEntry> entriesAt(double time) {
    final active = lines.indexWhere((l) => time >= l.start && time <= l.end);
    return buildMonetVisibleLineEntries(
      lines: lines,
      currentLineIndex: active,
      activeLine: active < 0 ? null : lines[active],
      recentCompletedLine: lines.reversed
          .where((l) => l.end < time)
          .firstOrNull,
      upcomingLine: lines.where((l) => l.start > time).firstOrNull,
      currentTime: time,
    );
  }

  for (final item in data['visible'] as List) {
    same(
      entriesAt((item['time'] as num).toDouble())
          .map((e) => e.toJson())
          .toList(),
      item['entries'],
      'visible ${item['time']}',
    );
  }
  for (final item in data['scroll'] as List) {
    same(
      buildScrollableRailEntries(
        lines,
        item['anchor'] as int,
        2,
      ).map((e) => e.toJson()).toList(),
      item['entries'],
      'scroll ${item['anchor']}',
    );
  }
  for (final item in data['positioned'] as List) {
    final entries = buildPositionedEntries(
      entries: entriesAt((item['time'] as num).toDouble()),
      railWidth: 360,
      railHeight: 420,
      lyricFontPx: inputs.fontPx,
      inactiveFontPx: 26,
      glowBufferPx: 44,
      inputs: inputs,
      cache: {},
      measure: measure,
    );
    same(
      entries
          .map(
            (e) => {
              ...e.entry.toJson(),
              'y': e.y,
              'scaledHeight': e.scaledHeight,
              'layout': e.layout.toJson(),
              'tone': {
                'opacity': e.tone.opacity,
                'scale': e.tone.scale,
                'blurPx': e.tone.blur,
                'baseColor': 'rgba(32, 52, 56, ${e.tone.baseAlpha})',
                'fontWeight': e.tone.fontWeight,
                'zIndex': e.tone.zIndex,
              },
            },
          )
          .toList(),
      item['entries'],
      'positioned ${item['time']}',
    );
  }
  for (final item in data['fill'] as List) {
    same(
      resolveMonetFillWidth((item['time'] as num).toDouble(), 3.4, 5, [
        0,
        11,
        22,
        33,
        44,
        55,
        66,
        77,
      ], buildWordGraphemeTimings(lines[2].words[2])),
      item['value'],
      'syllable fill ${item['time']}',
    );
  }
  for (var i = 0; i < lines.length; i++) {
    same(
      buildMonetLayoutCacheKey(
        MonetVisibleLineEntry(lines[i], i, 0, 'active'),
        inputs,
      ),
      data['cacheKeys'][i],
      'layout cache key $i',
    );
  }
  for (final item in data['fonts'] as List) {
    final theme = FoliaTheme.fromJson({
      'name': '',
      'backgroundColor': '#000000',
      'primaryColor': '#ffffff',
      'accentColor': '#aabbcc',
      'secondaryColor': '#888888',
      'animationIntensity': 'normal',
      ...Map<String, dynamic>.from(item['theme'] as Map),
    });
    same(resolveThemeFontStack(theme), item['lyric'], 'font stack');
    same(
      resolveThemeFontStack(theme, translation: true),
      item['translation'],
      'translation font stack',
    );
    same(resolveThemeFontWeight(theme, 600), item['weight'], 'theme weight');
  }
  for (final item in data['weights'] as List) {
    same(
      normalizeFontWeight(item['input']),
      item['value'],
      'weight ${item['input']}',
    );
  }
  final colors = data['colors'] as Map, entries = colors['wordColors'] as List;
  same(
    prepareWordColorMatchers(entries).map((m) => m.toJson()).toList(),
    colors['matchers'],
    'keyword matchers',
  );
  for (var i = 0; i < lines.length; i++) {
    final ranges = buildWordColorRanges(lines[i].text, entries);
    same(
      ranges.map((r) => r.toJson()).toList(),
      colors['cases'][i]['ranges'],
      'keyword ranges $i',
    );
    same(
      resolveTokenColorMap(buildMonetDisplayTokens(lines[i]), ranges),
      colors['cases'][i]['tokenColors'],
      'token colors $i',
    );
  }
  for (final item in colors['resolves'] as List) {
    final mode = switch (item['mode']) {
      'exact' => WordColorCjkMatchMode.exact,
      'bidirectional-contains' => WordColorCjkMatchMode.bidirectionalContains,
      _ => WordColorCjkMatchMode.targetContainsToken,
    };
    same(
      resolveWordColor(
        item['text'] as String,
        entries,
        '#000000',
        cjkMode: mode,
      ),
      item['value'],
      'word match ${item['text']}',
    );
  }
  var layers = <MonetPortraitLayer>[];
  for (final item in data['portraitEvents'] as List) {
    final event = item['event'] as List;
    layers = event[0] == 'push'
        ? pushMonetPortraitLayer(layers, event[1] as String, event[2] as String)
        : settleMonetPortraitLayers(layers, event[1] as String);
    same(
      layers.map((l) => l.toJson()).toList(),
      item['layers'],
      'portrait stack',
    );
    same(monetPortraitTargetSource(layers), item['target'], 'portrait target');
  }
  stdout.writeln(
    'Baseline timing, metadata, token, subtitle and rail geometry checks passed; font/visual parity remains unverified.',
  );
}

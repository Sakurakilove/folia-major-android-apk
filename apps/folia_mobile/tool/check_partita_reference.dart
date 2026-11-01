import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/lyrics/lyric_types.dart';
import 'package:folia_mobile/lyrics/word_segmentation.dart';
import 'package:folia_mobile/partita/partita_layout.dart';
import 'package:folia_mobile/partita/partita_tuning.dart';
import 'package:folia_mobile/partita/partita_word_layout.dart';

// A minimal source contract; supplied plain segmentation explicitly does not certify the native document preparation engine.
void main() {
  final data = jsonDecode(
    File('test/fixtures/partita_reference.json').readAsStringSync(),
  ) as Map;
  void equal(dynamic a, dynamic b, String at) {
    if (a is num && b is num && (a - b).abs() < 1e-8) return;
    if (a is Map && b is Map && a.length == b.length) {
      for (final key in b.keys) {
        equal(a[key], b[key], '$at.$key');
      }
      return;
    }
    if (a is List && b is List && a.length == b.length) {
      for (var i = 0; i < a.length; i++) {
        equal(a[i], b[i], '$at[$i]');
      }
      return;
    }
    if (a != b) throw StateError('$at: $a != $b');
  }

  for (final row in data['cases']) {
    final line = LyricLine.fromJson(
          Map<String, dynamic>.from(row['line'] as Map),
        ),
        tuning = PartitaTuning.resolve(
          {},
          Map<String, dynamic>.from(row['tuning'] as Map),
        );
    final plain = (row['plain'] as List)
        .map((s) => LyricWordSegment(s['segment'], s['index'], s['isWordLike']))
        .toList();
    final layout = buildPartitaLayout(
      line,
      row['intensity'],
      (row['height'] as num).toDouble(),
      tuning,
      segmentPlain: (_) => plain,
    );
    equal(layout.toJson(), row['layout'], 'layout');
    equal(
      partitaLayoutCacheKey(
        line,
        row['intensity'],
        619,
        (row['height'] as num).toDouble(),
        tuning,
      ),
      row['key'],
      'cache key',
    );
    equal(
      [
        for (final column in layout.columns)
          [
            for (final chunk in column.chunks)
              buildPartitaWordConfigs(
                chunk,
                row['intensity'],
              ).map((c) => c.toJson()).toList(),
          ],
      ],
      row['wordConfigs'],
      'word configurations',
    );
    final fonts = partitaFontSizes(
      layout.totalGraphemes,
      (row['fontScale'] as num).toDouble(),
    );
    equal(
      {
        'main': fonts.main,
        'empty': fonts.empty,
        'translation': fonts.translation,
        'upcoming': fonts.upcoming,
      },
      row['fonts'],
      'fonts',
    );
  }
  stdout.writeln(
    '${data['cases'].length} original Partita layouts/word configurations and font clamps passed.',
  );
}

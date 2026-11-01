import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/lyrics/icu_folia/icu_folia_engines.dart';
import 'package:folia_mobile/lyrics/icu_folia/icu_folia_segmenter.dart';
import 'package:folia_mobile/lyrics/icu_folia/jieba.dart';
import 'package:folia_mobile/lyrics/icu_folia/jieba_dictionary.dart';
import 'package:folia_mobile/lyrics/icu_folia/jieba_hmm.dart';

// Exact source boundary comparisons with supplied ICU pieces; the production Android ICU version still requires device compatibility verification.
void main() {
  Map read(String file) => jsonDecode(File(file).readAsStringSync()) as Map;
  final data = read('test/fixtures/icu_folia_reference.json'),
      dict = read('assets/icu_folia/dictionary.json'),
      hmm = read('assets/icu_folia/hmm.json'),
      japanese = read('assets/icu_folia/japanese.json'),
      lexicon = read('assets/icu_folia/lexicon.json');
  final engines = IcuFoliaEngines(
        dictionary: dict,
        hmm: hmm,
        japanese: japanese,
        lexicon: lexicon,
      ),
      segmenter = IcuFoliaSegmenter.fromJson(lexicon);
  void equal(dynamic a, dynamic b, String name) {
    if (a is List && b is List && a.length == b.length) {
      for (var i = 0; i < a.length; i++) {
        equal(a[i], b[i], '$name[$i]');
      }
      return;
    }
    if (a != b) throw StateError('$name: $a != $b');
  }

  for (final row in data['cases']) {
    final text = row['text'] as String,
        pieces = List<String>.from(row['plain'] as List);
    equal(
      segmenter.segment(text, pieces, engines: engines),
      row['expected'],
      'mixed $text',
    );
    equal(
      segmenter.segment(text, pieces),
      row['withoutEngines'],
      'no engines $text',
    );
    equal(engines.cutChinese(text), row['chinese'], 'Chinese $text');
    equal(engines.parseJapanese(text), row['japanese'], 'Japanese $text');
  }
  final raw = Jieba(JiebaDictionary.fromJson(dict), JiebaHmm.fromJson(hmm));
  for (final row in data['stock']) {
    equal(raw.cut(row[0]).join('/'), row[1], 'stock HMM ${row[0]}');
    equal(
      raw.cut(row[0], hmm: false).join('/'),
      row[2],
      'stock no HMM ${row[0]}',
    );
  }
  for (final row in data['updates']) {
    equal(
      raw.addWord(
        row['word'],
        frequency: (row['frequency'] as num?)?.toDouble(),
      ),
      row['expected'],
      'suggested weight ${row['word']}',
    );
  }
  stdout.writeln(
    '${data['cases'].length} original ICU-folia pipelines/engines, ${data['stock'].length} jieba lines and ${data['updates'].length} add_word weights passed; supplied ICU is not device proof.',
  );
}

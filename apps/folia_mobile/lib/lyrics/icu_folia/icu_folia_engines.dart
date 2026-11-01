import 'dart:typed_data';

import 'budoux_japanese.dart';
import 'icu_folia_segmenter.dart';
import 'jieba.dart';
import 'jieba_dictionary.dart';
import 'jieba_hmm.dart';

// Original default Chinese/Japanese engines on the exported baseline data, including exact fixed-lexicon weights/logs and length-preserving T2S.
class IcuFoliaEngines implements IcuFoliaCutters {
  IcuFoliaEngines({
    required Map dictionary,
    required Map hmm,
    required Map japanese,
    required Map lexicon,
  }) : jieba = Jieba(
         JiebaDictionary.fromJson(dictionary),
         JiebaHmm.fromJson(hmm),
         maxHmmWordLength: (lexicon['maxHmmWordLength'] as num).toDouble(),
       ),
       japanese = BudouxJapanese.fromJson(japanese) {
    final pairs = hmm['t2s'] as String;
    if (pairs.length.isOdd) {
      throw const FormatException('Invalid original T2S character pairs');
    }
    for (var i = 0; i < pairs.length; i += 2) {
      _simplified[pairs.codeUnitAt(i)] = pairs.codeUnitAt(i + 1);
    }
    for (final update in lexicon['updates'] as List) {
      jieba.addWord(
        update['word'] as String,
        frequency: (update['frequency'] as num).toDouble(),
        expectedTotal: (update['total'] as num).toDouble(),
        exactLogTotal: (update['logTotal'] as num).toDouble(),
        exactLogFrequency: (update['logFrequency'] as num).toDouble(),
      );
    }
  }
  final Jieba jieba;
  final BudouxJapanese japanese;
  final _simplified = Uint16List(65536);
  String simplify(String text) {
    final out = StringBuffer();
    for (final code in text.runes) {
      final mapped = code <= 0xffff ? _simplified[code] : 0;
      out.writeCharCode(mapped == 0 ? code : mapped);
    }
    return out.toString();
  }

  @override
  List<String> cutChinese(String text) {
    var cursor = 0;
    return [
      for (final word in jieba.cut(simplify(text)))
        (() {
          final original = text.substring(cursor, cursor + word.length);
          cursor += word.length;
          return original;
        })(),
    ];
  }

  @override
  List<String> parseJapanese(String text) => japanese.parse(text);
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'jieba_dictionary.dart';
import 'jieba_hmm.dart';
import 'jieba_text.dart';

part 'jieba_route.dart';

// Source icu-folia jieba pipeline: sorted dictionary, DAG route, HMM leftovers and mutable add_word overlay, without a word-sized hash dictionary.
class Jieba {
  Jieba(this.dictionary, this.hmm, {this.maxHmmWordLength = double.infinity})
    : _total = dictionary.total,
      _logTotal = dictionary.logTotal;
  final JiebaDictionary dictionary;
  final JiebaHmm hmm;
  final double maxHmmWordLength;
  double _total, _logTotal;
  final _added = <String, double>{},
      _addedPrefixes = <String>{},
      _addedFirstCodes = <int>{};
  static final _han = RegExp(
        r'([㐀-䶿一-鿿豈-﫿\u{20000}-\u{2A6DF}\u{2A700}-\u{2B73F}\u{2B740}-\u{2B81F}\u{2B820}-\u{2CEAF}\u{2CEB0}-\u{2EBEF}\u{2F800}-\u{2FA1F}a-zA-Z0-9+#&._%-]+)',
        unicode: true,
      ),
      _skip = RegExp(r'(\r\n|\s)', unicode: true),
      _latin = RegExp(r'^[a-zA-Z0-9]$');
  static bool _truthy(double value) => value != 0 && !value.isNaN;

  double frequencyOf(String word) {
    final added = _added[word];
    if (added != null) return added;
    final index = dictionary.lowerBound(word, 0, word.length);
    return index < dictionary.count &&
            dictionary.compareAt(index, word, 0, word.length) == 0
        ? dictionary.frequencies[index].toDouble()
        : 0;
  }

  List<String> cut(String text, {bool hmm = true}) {
    final out = <String>[];
    for (final block in jiebaSplitKeep(text, _han)) {
      if (block.matched) {
        _cutBlock(block.text, hmm, out);
        continue;
      }
      for (final piece in jiebaSplitKeep(block.text, _skip)) {
        if (piece.matched) {
          out.add(piece.text);
        } else {
          out.addAll(piece.text.runes.map(String.fromCharCode));
        }
      }
    }
    return out;
  }

  void _cutBlock(String text, bool useHmm, List<String> out) {
    final bounds = Int32List(text.runes.length + 1);
    var index = 0, offset = 0;
    for (final code in text.runes) {
      offset += code > 0xffff ? 2 : 1;
      bounds[++index] = offset;
    }
    final next = _route(text, bounds), buffer = <String>[];
    void flush() {
      if (buffer.length == 1) {
        out.add(buffer.first);
      } else if (buffer.length > 1) {
        final run = buffer.join();
        if (!_truthy(frequencyOf(run))) {
          hmm.cut(run, out, maxHmmWordLength);
        } else {
          out.addAll(buffer);
        }
      }
      buffer.clear();
    }

    var latin = '';
    for (var i = 0; i < bounds.length - 1;) {
      final end = next[i], word = text.substring(bounds[i], bounds[end]);
      if (!useHmm) {
        if (end - i == 1 && _latin.hasMatch(word)) {
          latin += word;
        } else {
          if (latin.isNotEmpty) out.add(latin);
          latin = '';
          out.add(word);
        }
      } else if (end - i == 1) {
        buffer.add(word);
      } else {
        flush();
        out.add(word);
      }
      i = end;
    }
    if (useHmm) {
      flush();
    } else if (latin.isNotEmpty) {
      out.add(latin);
    }
  }

  double suggestFrequency(String word) {
    var logFrequency = 0.0;
    for (final piece in cut(word, hmm: false)) {
      final frequency = frequencyOf(piece);
      logFrequency =
          logFrequency +
          dictionary.logFrequency(_truthy(frequency) ? frequency : 1) -
          _logTotal;
    }
    final existing = frequencyOf(word);
    return math.max(
      (math.exp(logFrequency + _logTotal).floor() + 1).toDouble(),
      _truthy(existing) ? existing : 1,
    );
  }

  double addWord(
    String word, {
    double? frequency,
    double? exactLogTotal,
    double? exactLogFrequency,
    double? expectedTotal,
  }) {
    final weight = frequency ?? suggestFrequency(word);
    _total += weight - frequencyOf(word);
    if (expectedTotal != null && _total != expectedTotal) {
      throw const FormatException(
        'Default jieba lexicon total differs from baseline',
      );
    }
    _logTotal = exactLogTotal ?? math.log(_total);
    dictionary.seedLog(weight, exactLogFrequency ?? math.log(weight));
    _added[word] = weight;
    if (word.isNotEmpty) _addedFirstCodes.add(word.codeUnitAt(0));
    var prefix = '';
    for (final code in word.runes) {
      prefix += String.fromCharCode(code);
      _addedPrefixes.add(prefix);
    }
    return weight;
  }
}

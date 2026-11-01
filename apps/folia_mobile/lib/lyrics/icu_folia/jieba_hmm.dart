import 'dart:convert';
import 'dart:typed_data';

import 'jieba_text.dart';

// Source finalseg Viterbi: B/E/M/S index order, exact little-endian emit doubles and later-state tie breaks are observable word boundaries.
class JiebaHmm {
  JiebaHmm.fromJson(Map data) {
    const states = ['B', 'E', 'M', 'S'];
    start = [for (final s in states) (data['start'][s] as num).toDouble()];
    trans = [
      for (final from in states)
        [
          for (final to in states)
            (data['trans'][from][to] as num?)?.toDouble() ?? minFloat,
        ],
    ];
    emit = [for (final state in states) _readEmit(data['emit'][state] as List)];
  }
  static const minFloat = -3.14e100;
  static const _previous = [
    [1, 3],
    [0, 2],
    [2, 0],
    [3, 1],
  ];
  static final _han = RegExp(r'([一-鿕]+)', unicode: true),
      _skip = RegExp(r'([a-zA-Z0-9]+(?:\.\d+)?%?)', unicode: true);
  late final List<double> start;
  late final List<List<double>> trans;
  late final List<Map<int, double>> emit;
  static Map<int, double> _readEmit(List pair) {
    final bytes = base64Decode(pair[1] as String),
        data = ByteData.sublistView(bytes),
        out = <int, double>{};
    var index = 0;
    for (final code in (pair[0] as String).runes) {
      out[code] = data.getFloat64(index++ * 8, Endian.little);
    }
    if (index * 8 != bytes.length) {
      throw const FormatException('Invalid original HMM emit data');
    }
    return out;
  }

  Int8List labels(List<int> chars) {
    final n = chars.length, probs = Float64List(n * 4), back = Int8List(n * 4);
    for (var s = 0; s < 4; s++) {
      probs[s] = start[s] + (emit[s][chars.first] ?? minFloat);
    }
    for (var t = 1; t < n; t++) {
      for (var s = 0; s < 4; s++) {
        final emission = emit[s][chars[t]] ?? minFloat;
        var best = double.negativeInfinity, bestPrevious = -1;
        for (final previous in _previous[s]) {
          final p =
              probs[(t - 1) * 4 + previous] + trans[previous][s] + emission;
          if (p > best || p == best && previous > bestPrevious) {
            best = p;
            bestPrevious = previous;
          }
        }
        probs[t * 4 + s] = best;
        back[t * 4 + s] = bestPrevious;
      }
    }
    var state = probs[(n - 1) * 4 + 3] >= probs[(n - 1) * 4 + 1] ? 3 : 1;
    final out = Int8List(n);
    for (var t = n - 1; t >= 0; t--) {
      out[t] = state;
      state = back[t * 4 + state];
    }
    return out;
  }

  void cut(String text, List<String> out, double maxWordLength) {
    for (final block in jiebaSplitKeep(text, _han)) {
      if (!block.matched) {
        for (final piece in jiebaSplitKeep(block.text, _skip)) {
          out.add(piece.text);
        }
        continue;
      }
      final chars = block.text.runes.toList(growable: false),
          states = labels(block.text.runes.toList(growable: false)),
          words = <String>[];
      var begin = 0, next = 0;
      for (var i = 0; i < states.length; i++) {
        if (states[i] == 0) {
          begin = i;
        } else if (states[i] == 1) {
          words.add(String.fromCharCodes(chars.sublist(begin, i + 1)));
          next = i + 1;
        } else if (states[i] == 3) {
          words.add(String.fromCharCode(chars[i]));
          next = i + 1;
        }
      }
      if (next < chars.length) {
        words.add(String.fromCharCodes(chars.sublist(next)));
      }
      for (final word in words) {
        if (word.runes.length > maxWordLength) {
          out.addAll(word.runes.map(String.fromCharCode));
        } else {
          out.add(word);
        }
      }
    }
  }
}

part of 'jieba.dart';

// One lower-bound lookup supplies prefix and frequency together; the original two searches had identical keys and no observable side effects.
class _JiebaLookup {
  double frequency = 0;
  bool prefix = false;
}

extension _JiebaRouting on Jieba {
  void _lookup(String text, int from, int to, _JiebaLookup out) {
    double? extra;
    var extraPrefix = false;
    if (from < to && _addedFirstCodes.contains(text.codeUnitAt(from))) {
      final key = text.substring(from, to);
      extra = _added[key];
      extraPrefix = _addedPrefixes.contains(key);
    }
    if (extraPrefix && extra != null) {
      out
        ..frequency = extra
        ..prefix = true;
      return;
    }
    final index = dictionary.lowerBound(text, from, to),
        prefix = dictionary.prefixAt(index, text, from, to);
    out.prefix = extraPrefix || prefix;
    out.frequency =
        extra ??
        (prefix &&
                dictionary.starts[index + 1] - 1 - dictionary.starts[index] ==
                    to - from
            ? dictionary.frequencies[index].toDouble()
            : 0);
  }

  Int32List _route(String text, Int32List bounds) {
    final n = bounds.length - 1,
        best = Float64List(n + 1),
        next = Int32List(n + 1),
        lookup = _JiebaLookup();
    for (var i = n - 1; i >= 0; i--) {
      var probability = double.negativeInfinity,
          bestEnd = i,
          end = i,
          found = false;
      while (end < n) {
        _lookup(text, bounds[i], bounds[end + 1], lookup);
        if (!lookup.prefix) break;
        if (Jieba._truthy(lookup.frequency)) {
          found = true;
          final p =
              dictionary.logFrequency(lookup.frequency) -
              _logTotal +
              best[end + 1];
          if (p >= probability) {
            probability = p;
            bestEnd = end;
          }
        }
        end++;
      }
      if (!found) {
        probability = 0 - _logTotal + best[i + 1];
        bestEnd = i;
      }
      best[i] = probability;
      next[i] = bestEnd + 1;
    }
    return next;
  }
}

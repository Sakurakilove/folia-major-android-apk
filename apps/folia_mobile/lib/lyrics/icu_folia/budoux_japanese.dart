// Copyright 2021 Google LLC. Apache-2.0; see assets/icu_folia/Apache-2.0.txt and NOTICE.txt. Port of the pinned BudouX Parser's Japanese numeric path.
class BudouxJapanese {
  BudouxJapanese.fromJson(Map data) {
    var sum = 0.0;
    for (final entry in data.entries) {
      final values = <String, double>{};
      for (final weight in (entry.value as Map).entries) {
        final v = (weight.value as num).toDouble();
        values[weight.key as String] = v;
        sum += v;
      }
      _model[entry.key as String] = values;
    }
    _baseScore = -.5 * sum;
  }
  final _model = <String, Map<String, double>>{};
  late final double _baseScore;
  static String _substring(String text, int from, int to) {
    final a = from.clamp(0, text.length), b = to.clamp(0, text.length);
    return a <= b ? text.substring(a, b) : text.substring(b, a);
  }

  static const _features = [
    ('UW1', -3, -2),
    ('UW2', -2, -1),
    ('UW3', -1, 0),
    ('UW4', 0, 1),
    ('UW5', 1, 2),
    ('UW6', 2, 3),
    ('BW1', -2, 0),
    ('BW2', -1, 1),
    ('BW3', 0, 2),
    ('TW1', -3, 0),
    ('TW2', -2, 1),
    ('TW3', -1, 2),
    ('TW4', 0, 3),
  ];
  List<String> parse(String text) {
    if (text.isEmpty) return [];
    final out = <String>[];
    var start = 0;
    // Source BudouX intentionally indexes UTF-16 code units here; changing it to graphemes would change model scores and offsets.
    for (var i = 1; i < text.length; i++) {
      var score = _baseScore;
      for (final feature in _features) {
        score +=
            _model[feature.$1]?[_substring(
              text,
              i + feature.$2,
              i + feature.$3,
            )] ??
            0;
      }
      if (score > 0) {
        out.add(text.substring(start, i));
        start = i;
      }
    }
    out.add(text.substring(start));
    return out;
  }
}

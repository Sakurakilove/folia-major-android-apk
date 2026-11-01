import 'dart:math' as math;

import 'lyric_types.dart';

// Same immutable index and latest-active overlap semantics as utils/lyrics/activeLineIndex.ts.
class ActiveLineLookup {
  ActiveLineLookup(List<LyricLine> lines)
    : _lines = List.unmodifiable(lines),
      _starts = List.filled(lines.length, 0),
      _ends = List.filled(lines.length, 0),
      _prefixEnds = List.filled(lines.length, 0) {
    var furthest = double.negativeInfinity;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i],
          start = line.start,
          end = line.renderHints?.renderEndTime ?? line.end;
      if (!start.isFinite ||
          !end.isFinite ||
          (i > 0 && start < _starts[i - 1])) {
        _ordered = false;
      }
      _starts[i] = start;
      _ends[i] = end;
      furthest = math.max(furthest, end);
      _prefixEnds[i] = furthest;
    }
  }
  final List<LyricLine> _lines;
  final List<double> _starts, _ends, _prefixEnds;
  bool _ordered = true;

  int call(double time) {
    if (!_ordered || !time.isFinite) {
      for (var i = _lines.length - 1; i >= 0; i--) {
        if (!(time < _starts[i]) && time <= _ends[i]) return i;
      }
      return -1;
    }
    var low = 0, high = _starts.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_starts[mid] <= time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    for (var i = low - 1; i >= 0 && _prefixEnds[i] >= time; i--) {
      if (_ends[i] >= time) return i;
    }
    return -1;
  }
}

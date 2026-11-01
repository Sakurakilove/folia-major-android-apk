import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

// Baseline jieba's sorted UTF-16 dictionary, without a 349k-entry string-key hash map; exact build-time JS logs avoid route differences from libm.
class JiebaDictionary {
  JiebaDictionary.fromJson(Map data)
    : words = data['words'] as String,
      total = (data['total'] as num).toDouble(),
      logTotal = (data['logTotal'] as num).toDouble() {
    var count = words.isEmpty ? 0 : 1;
    for (var i = 0; i < words.length; i++) {
      if (words.codeUnitAt(i) == 10) count++;
    }
    starts = Int32List(count + 1);
    for (var i = 0, word = 1; i < words.length; i++) {
      if (words.codeUnitAt(i) == 10) starts[word++] = i + 1;
    }
    starts[count] = words.length + 1;
    final bytes = base64Decode(data['freqs'] as String);
    frequencies = Uint32List(count);
    var cursor = 0;
    for (var i = 0; i < count; i++) {
      var value = 0, shift = 0;
      while (true) {
        if (cursor >= bytes.length || shift > 28) {
          throw const FormatException('Invalid original jieba frequency data');
        }
        final byte = bytes[cursor++];
        value |= (byte & 127) << shift;
        if (byte < 128) break;
        shift += 7;
      }
      frequencies[i] = value;
    }
    if (cursor != bytes.length) {
      throw const FormatException('Trailing jieba frequency data');
    }
    for (final pair in data['logFrequencies'] as List) {
      _logs[(pair[0] as num).toDouble()] = (pair[1] as num).toDouble();
    }
  }
  final String words;
  final double total, logTotal;
  late final Int32List starts;
  late final Uint32List frequencies;
  final _logs = <double, double>{};
  int get count => frequencies.length;
  double logFrequency(double frequency) =>
      _logs.putIfAbsent(frequency, () => math.log(frequency));
  void seedLog(double frequency, double value) => _logs[frequency] = value;
  int compareAt(int index, String text, int from, int to) {
    final start = starts[index],
        length = starts[index + 1] - 1 - start,
        shared = math.min(length, to - from);
    for (var offset = 0; offset < shared; offset++) {
      final difference =
          words.codeUnitAt(start + offset) - text.codeUnitAt(from + offset);
      if (difference != 0) return difference;
    }
    return length - (to - from);
  }

  int lowerBound(String text, int from, int to) {
    var low = 0, high = count;
    while (low < high) {
      final mid = (low + high) >>> 1;
      if (compareAt(mid, text, from, to) < 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  bool prefixAt(int index, String text, int from, int to) {
    if (index >= count || starts[index + 1] - 1 - starts[index] < to - from) {
      return false;
    }
    for (var i = 0; i < to - from; i++) {
      if (words.codeUnitAt(starts[index] + i) != text.codeUnitAt(from + i)) {
        return false;
      }
    }
    return true;
  }
}

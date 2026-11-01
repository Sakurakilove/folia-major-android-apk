part of 'native_word_segmentation.dart';

// The input text already lives in Dart: native replies only carry compact end/status pairs, never another copy of each segment string.
Iterable<List<String>> _wordBatches(List<String> texts) sync* {
  var batch = <String>[], units = 0;
  for (final text in texts) {
    if (batch.isNotEmpty &&
        (batch.length >= 128 || units + text.length > 65536)) {
      yield batch;
      batch = [];
      units = 0;
    }
    batch.add(text);
    units += text.length;
  }
  if (batch.isNotEmpty) yield batch;
}

List<LyricWordSegment> _decodeWordPairs(String text, dynamic data) {
  if (data is! List<int> || data.length.isOdd) {
    throw const FormatException('Invalid native UTF-16 word pairs');
  }
  final out = <LyricWordSegment>[];
  var cursor = 0;
  for (var i = 0; i < data.length; i += 2) {
    final end = data[i], status = data[i + 1];
    if (end <= cursor || end > text.length) {
      throw const FormatException('Invalid native UTF-16 word boundary');
    }
    out.add(
      LyricWordSegment(
        text.substring(cursor, end),
        cursor,
        status >= 100 && status < 500,
      ),
    );
    cursor = end;
  }
  if (cursor != text.length) {
    throw const FormatException(
      'Native word boundaries did not rebuild the source',
    );
  }
  return List.unmodifiable(out);
}

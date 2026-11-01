// Capturing JS String.split behavior, with empty pieces removed; Dart String.split does not retain the capture groups.
Iterable<({String text, bool matched})> jiebaSplitKeep(
  String text,
  RegExp pattern,
) sync* {
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (cursor < match.start) {
      yield (text: text.substring(cursor, match.start), matched: false);
    }
    if (match.end > match.start) yield (text: match[1]!, matched: true);
    cursor = match.end;
  }
  if (cursor < text.length) {
    yield (text: text.substring(cursor), matched: false);
  }
}

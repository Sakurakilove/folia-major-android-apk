// ECMAScript TrimString differs from Dart trim (for example, U+0085 is not JavaScript whitespace).
const jsWhitespacePattern =
    r'\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF';
final _start = RegExp('^[$jsWhitespacePattern]+'),
    _end = RegExp('[$jsWhitespacePattern]+\$');
String jsTrimEnd(String value) => value.replaceFirst(_end, '');
String jsTrim(String value) => jsTrimEnd(value.replaceFirst(_start, ''));

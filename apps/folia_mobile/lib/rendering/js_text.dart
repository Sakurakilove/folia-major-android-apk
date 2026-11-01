// ECMAScript TrimString differs from Dart trim (for example, U+0085 is not JavaScript whitespace).
const _jsSpace =
    r'\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF';
final _start = RegExp('^[$_jsSpace]+'), _end = RegExp('[$_jsSpace]+\$');
String jsTrimEnd(String value) => value.replaceFirst(_end, '');
String jsTrim(String value) => jsTrimEnd(value.replaceFirst(_start, ''));

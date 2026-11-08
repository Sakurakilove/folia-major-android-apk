import 'dart:typed_data';

// StandardMethodCodec UTF-8 replaces isolated surrogates and Dart strips an initial BOM. Preserve exceptional source strings as little-endian units; ordinary documents keep the normal string path.
abstract final class NativeWordText {
  static Object encode(String text) {
    var malformed = text.startsWith('\ufeff');
    for (var i = 0; !malformed && i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 0xd800 && c <= 0xdbff) {
        if (i + 1 < text.length &&
            text.codeUnitAt(i + 1) >= 0xdc00 &&
            text.codeUnitAt(i + 1) <= 0xdfff) {
          i++;
        } else {
          malformed = true;
          break;
        }
      } else if (c >= 0xdc00 && c <= 0xdfff) {
        malformed = true;
        break;
      }
    }
    if (!malformed) return text;
    final bytes = Uint8List(text.length * 2);
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      bytes[i * 2] = c & 255;
      bytes[i * 2 + 1] = c >> 8;
    }
    return bytes;
  }

  static String decode(Object? value) {
    if (value is String) return value;
    if (value is! Uint8List || value.length.isOdd) {
      throw const FormatException('Invalid native UTF-16 text');
    }
    return String.fromCharCodes([
      for (var i = 0; i < value.length; i += 2) value[i] | (value[i + 1] << 8),
    ]);
  }
}

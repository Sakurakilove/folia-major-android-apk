import 'dart:io';

import 'package:folia_mobile/rendering/css_case.dart';
import 'package:folia_mobile/rendering/css_text.dart';

// Concrete cross-runtime regressions: these expansions cannot be reproduced by Dart's simple uppercase.
void main() {
  const cases = {
    'Straße': 'STRASSE',
    'ﬃ': 'FFI',
    'ᾀ': 'ἈΙ',
    'ῳ': 'ΩΙ',
    '世界': '世界',
  };
  for (final entry in cases.entries) {
    if (cssUppercase(entry.key) != entry.value) {
      throw StateError('Full uppercase differs for ${entry.key}');
    }
  }
  if (cssNormalText(' \tfirst\n second\r\n ') != 'first second' ||
      cssNormalText('\u00a0 x \u00a0') != '\u00a0 x \u00a0') {
    throw StateError('CSS normal whitespace or NBSP changed');
  }
  stdout.writeln(
    'Full uppercase expansion and CSS normal whitespace regressions passed; browser/font parity remains unverified.',
  );
}

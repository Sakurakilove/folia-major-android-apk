import 'css_uppercase_data.dart';

// Preserve the original full uppercase expansions without a platform call or a late-loaded case table on the first frame.
String cssUppercase(String text) {
  final output = StringBuffer();
  for (final code in text.runes) {
    output.write(cssUppercaseMappings[code] ?? String.fromCharCode(code));
  }
  return output.toString();
}

// CSS normal/nowrap collapses ASCII segment whitespace; NBSP and other non-collapsible code points remain intact.
final _collapsibleWhitespace = RegExp(r'[\t\n\r\f ]+');
String cssNormalText(String text) => text
    .replaceAll(_collapsibleWhitespace, ' ')
    .replaceFirst(RegExp(r'^ '), '')
    .replaceFirst(RegExp(r' $'), '');

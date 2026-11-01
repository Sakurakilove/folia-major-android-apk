import 'folia_theme.dart';

// Port of utils/fontStacks.ts; named fallbacks and translation-specific ordering are part of appearance.
const builtinFontStacks = {
  'sans': [
    'Inter',
    'Noto Sans CJK SC',
    'Noto Sans JP',
    'Source Han Sans SC',
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ],
  'serif': [
    '獅尾四季春加糖SC',
    'Iowan Old Style',
    'Noto Serif CJK SC',
    'Noto Serif JP',
    'Source Han Serif SC',
    'Songti SC',
    'STSong',
    'Georgia',
    'serif',
  ],
  'mono': [
    'IBM Plex Mono',
    'Sarasa Mono SC',
    'Noto Sans Mono CJK SC',
    'Noto Sans Mono',
    'SFMono-Regular',
    'Consolas',
    'monospace',
  ],
};

const translationFontStacks = {
  'sans': [
    'system-ui',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Inter',
    'Helvetica Neue',
    'Arial',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'Noto Sans JP',
    'Source Han Sans JP',
    'Hiragino Sans',
    'Yu Gothic',
    'Meiryo',
    'sans-serif',
  ],
  'serif': [
    '獅尾四季春加糖SC',
    'Folia Noto Serif SC',
    'Iowan Old Style',
    'Georgia',
    'Times New Roman',
    'Noto Serif CJK SC',
    'Source Han Serif SC',
    'Songti SC',
    'STSong',
    'SimSun',
    'Noto Serif JP',
    'Source Han Serif JP',
    'Yu Mincho',
    'MS PMincho',
    'serif',
  ],
  'mono': [
    'Consolas',
    'IBM Plex Mono',
    'SFMono-Regular',
    'Menlo',
    'Monaco',
    'Sarasa Mono SC',
    'Noto Sans Mono CJK SC',
    'SimHei',
    'DengXian',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Noto Sans Mono CJK JP',
    'MS Gothic',
    'monospace',
  ],
};

int? normalizeFontWeight(Object? value) => value is num && value.isFinite
    ? (value.clamp(100, 900) / 10).round() * 10
    : null;
int resolveThemeFontWeight(FoliaTheme? theme, int fallback) =>
    normalizeFontWeight(theme?.fontWeight) ?? fallback;

String _normalize(String text) => text
    .trim()
    .replaceFirst(RegExp(r'''^['"]'''), '')
    .replaceFirst(RegExp(r'''['"]$'''), '')
    .trim();

List<String> normalizeFontFamilyStack(Iterable<String?>? families) {
  final seen = <String>{}, result = <String>[];
  for (final family in families ?? <String>[]) {
    final normalized = _normalize(family ?? '');
    if (normalized.isEmpty || !seen.add(normalized.toLowerCase())) continue;
    result.add(normalized);
  }
  return List.unmodifiable(result);
}

List<String> resolveThemeFontFamilies(
  FoliaTheme theme, {
  bool translation = false,
}) => [
  ...normalizeFontFamilyStack([theme.fontFamily, ...theme.fontFamilyStack]),
  ...(translation
          ? translationFontStacks
          : builtinFontStacks)[theme.fontStyle] ??
      (translation ? translationFontStacks : builtinFontStacks)['sans']!,
];

// CSS strings preserve source keys for migrated settings/export and differential checks, not a Flutter font alias.
const _generic = {
  'serif',
  'sans-serif',
  'monospace',
  'cursive',
  'fantasy',
  'system-ui',
  'ui-serif',
  'ui-sans-serif',
  'ui-monospace',
  'ui-rounded',
  'emoji',
  'math',
  'fangsong',
};
String _quote(String family) =>
    '"${family.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
String _customFontString(String family) =>
    _generic.contains(family.toLowerCase()) ? family : _quote(family);

const _builtinCss = {
  'sans': '"Inter", "Noto Sans CJK SC", "Noto Sans JP", "Source Han Sans SC", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Helvetica Neue", Arial, sans-serif',
  'serif': '"獅尾四季春加糖SC", "Iowan Old Style", "Noto Serif CJK SC", "Noto Serif JP", "Source Han Serif SC", "Songti SC", "STSong", "Georgia", serif',
  'mono': '"IBM Plex Mono", "Sarasa Mono SC", "Noto Sans Mono CJK SC", "Noto Sans Mono", "SFMono-Regular", Consolas, monospace',
};
const _translationCss = {
  'sans': 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", "Inter", "Helvetica Neue", Arial, "Noto Sans CJK SC", "Source Han Sans SC", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans JP", "Source Han Sans JP", "Hiragino Sans", "Yu Gothic", Meiryo, sans-serif',
  'serif': '"獅尾四季春加糖SC", "Folia Noto Serif SC", "Iowan Old Style", Georgia, "Times New Roman", "Noto Serif CJK SC", "Source Han Serif SC", "Songti SC", "STSong", "SimSun", "Noto Serif JP", "Source Han Serif JP", "Yu Mincho", "MS PMincho", serif',
  'mono': 'Consolas, "IBM Plex Mono", "SFMono-Regular", Menlo, Monaco, "Sarasa Mono SC", "Noto Sans Mono CJK SC", "SimHei", "DengXian", "Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans Mono CJK JP", "MS Gothic", monospace',
};

String getBuiltinThemeFontStack(String style) =>
    _builtinCss[style] ?? _builtinCss['sans']!;
String resolveThemeFontStack(FoliaTheme theme, {bool translation = false}) {
  final stacks = translation ? _translationCss : _builtinCss;
  final fallback = stacks[theme.fontStyle] ?? stacks['sans']!;
  final custom = normalizeFontFamilyStack([
    theme.fontFamily,
    ...theme.fontFamilyStack,
  ]);
  return custom.isEmpty
      ? fallback
      : '${custom.map(_customFontString).join(', ')}, $fallback';
}

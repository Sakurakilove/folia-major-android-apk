part of 'monet_rail.dart';

// Configuration logic stays outside the rail widget assembly.
extension _MonetRailConfiguration on _MonetRailState {
  void _configuration() {
    final theme = widget.theme, sub = widget.subtitleTheme ?? theme;
    _lyricStack = resolveThemeFontStack(theme);
    _subtitleStack = resolveThemeFontStack(sub, translation: true);
    _lyric = FoliaTypography.fromTheme(theme, fontsEpoch: widget.fontsEpoch);
    _subtitle = FoliaTypography.fromTheme(
      sub,
      translation: true,
      fallbackWeight: 500,
      height: 1.28,
      fontsEpoch: widget.fontsEpoch,
    );
    _secondarySubtitle = FoliaTypography.fromTheme(
      sub,
      translation: true,
      fallbackWeight: 400,
      height: 1.28,
      fontsEpoch: widget.fontsEpoch,
    );
    _primary = widget.resolveColor(theme.primaryColor);
    _accent = widget.resolveColor(theme.accentColor);
    _background = widget.resolveColor(theme.backgroundColor);
    _matchers = prepareWordColorMatchers(
      theme.wordColors,
      enabled: widget.keywordColoringEnabled,
    );
    _measure = MonetNativeTextMeasurement((stack, weight) {
      final typography = stack == _subtitleStack && weight != _lyric.weight
          ? weight == _secondarySubtitle.weight
                ? _secondarySubtitle
                : _subtitle
          : _lyric;
      return FoliaTypography(
        families: stack == _subtitleStack
            ? _subtitle.families
            : _lyric.families,
        weight: weight,
        height: typography.height,
        fontsEpoch: widget.fontsEpoch,
      );
    });
    _layouts.clear();
    _needsLayout = true;
    _lastPaintPosition = null;
  }
}

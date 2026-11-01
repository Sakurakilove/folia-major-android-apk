// src/types.ts Theme and DualTheme retain the original schema; native rendering consumes these values directly.
class FoliaTheme {
  FoliaTheme.fromJson(Map<String, dynamic> data)
    : source = Map.unmodifiable(data),
      name = data['name'] as String,
      backgroundColor = data['backgroundColor'] as String,
      primaryColor = data['primaryColor'] as String,
      accentColor = data['accentColor'] as String,
      secondaryColor = data['secondaryColor'] as String,
      fontStyle = data['fontStyle'] as String,
      fontFamily = data['fontFamily'] as String?,
      fontFamilyStack = List<String>.unmodifiable(
        data['fontFamilyStack'] as List? ?? const [],
      ),
      fontWeight = data['fontWeight'] as num?,
      animationIntensity = data['animationIntensity'] as String,
      wordColors = List<dynamic>.unmodifiable(
        data['wordColors'] as List? ?? const [],
      ),
      lyricsIcons = List<String>.unmodifiable(
        data['lyricsIcons'] as List? ?? const [],
      ),
      provider = data['provider'] as String?,
      description = data['description'] as String?;
  final Map<String, dynamic> source;
  final String name,
      backgroundColor,
      primaryColor,
      accentColor,
      secondaryColor,
      fontStyle,
      animationIntensity;
  final String? fontFamily, provider, description;
  final List<String> fontFamilyStack, lyricsIcons;
  final num? fontWeight;
  final List<dynamic> wordColors;
  Map<String, dynamic> toJson() => Map.of(source);
}

class FoliaDualTheme {
  FoliaDualTheme.fromJson(Map<String, dynamic> data)
    : light = FoliaTheme.fromJson(
        Map<String, dynamic>.from(data['light'] as Map),
      ),
      dark = FoliaTheme.fromJson(
        Map<String, dynamic>.from(data['dark'] as Map),
      ),
      source = Map.unmodifiable(data);
  final FoliaTheme light, dark;
  final Map<String, dynamic> source;
  Map<String, dynamic> toJson() => {
    ...source,
    'light': light.toJson(),
    'dark': dark.toJson(),
  };
}

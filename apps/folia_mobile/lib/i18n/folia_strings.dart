import 'dart:convert';

import 'package:flutter/services.dart';

// Original locale dictionaries and config.ts language/fallback rules, without per-frame bridge traffic.
const appLanguageStorageKey = 'folia_app_language';
const supportedAppLanguages = ['en', 'zh-CN', 'zh-TW', 'in'];

String normalizeSupportedLanguage(String? language) {
  if (language == null || language.isEmpty) return 'en';
  final lower = language.toLowerCase();
  if (language == 'in' || lower.startsWith('id')) return 'in';
  if (lower.startsWith('zh')) {
    final subtags = lower.split('-').skip(1);
    return subtags.any((tag) => const {'hant', 'tw', 'hk', 'mo'}.contains(tag))
        ? 'zh-TW'
        : 'zh-CN';
  }
  return 'en';
}

String readAppLanguagePreference(String? stored) =>
    stored == 'system' || supportedAppLanguages.contains(stored)
    ? stored!
    : 'system';

dynamic _lookup(Map<String, dynamic> data, String key) {
  dynamic value = data;
  for (final part in key.split('.')) {
    if (value is Map) {
      value = value[part];
    } else if (value is List && int.tryParse(part) != null) {
      final index = int.parse(part);
      value = index >= 0 && index < value.length ? value[index] : null;
    } else {
      return null;
    }
  }
  return value;
}

class FoliaStrings {
  FoliaStrings({
    required this.language,
    required Map<String, dynamic> locale,
    required Map<String, dynamic> english,
    required Map<String, dynamic> chinese,
  }) : _locale = Map.unmodifiable(locale),
       _english = Map.unmodifiable(english),
       _chinese = Map.unmodifiable(chinese);
  final String language;
  final Map<String, dynamic> _locale, _english, _chinese;

  static Future<FoliaStrings> load(
    String language, {
    AssetBundle? assets,
  }) async {
    final bundle = assets ?? rootBundle,
        normalized = normalizeSupportedLanguage(language);
    final requests = <String, Future<Map<String, dynamic>>>{};
    Future<Map<String, dynamic>> read(String language) => requests.putIfAbsent(
      language,
      () async => Map<String, dynamic>.from(
        jsonDecode(
          await bundle.loadString('assets/original/locales/$language.json'),
        ) as Map,
      ),
    );
    final data = await Future.wait([
      read(normalized),
      read('en'),
      read('zh-CN'),
    ]);
    return FoliaStrings(
      language: normalized,
      locale: data[0],
      english: data[1],
      chinese: data[2],
    );
  }

  dynamic value(String key) =>
      _lookup(_locale, key) ?? _lookup(_english, key) ?? _lookup(_chinese, key);

  String t(
    String key, {
    Map<String, dynamic> args = const {},
    String? defaultValue,
  }) {
    final count = args['count'];
    dynamic text;
    // These are the original app's supported CLDR cardinal categories: English one/other; zh/id other.
    for (final (dictionary, locale) in [
      (_locale, language),
      (_english, 'en'),
    ]) {
      if (count is num) {
        if (count == 0) text = _lookup(dictionary, '${key}_zero');
        text ??= _lookup(
          dictionary,
          '${key}_${locale == 'en' && count.abs() == 1 ? 'one' : 'other'}',
        );
      }
      text ??= _lookup(dictionary, key);
      if (text != null) break;
    }
    text ??= _lookup(_chinese, key) ?? defaultValue ?? key;
    if (text is! String) return text.toString();
    return text.replaceAllMapped(RegExp(r'\{\{\s*(-\s*)?([^{}]+?)\s*\}\}'), (
      match,
    ) {
      final argument = _lookup(args, match[2]!.trim());
      if (argument == null) return match[0]!;
      return argument is double && argument == argument.truncateToDouble()
          ? argument.toInt().toString()
          : argument.toString();
    });
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/i18n/folia_strings.dart';
import 'package:folia_mobile/rendering/folia_icons.dart';

// Validate the new native resource path once; no emulator, UI screenshots or timing benchmarks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every exported Lucide primitive decodes without changing its node data',
    () {
      final files = Directory('assets/original/icons')
          .listSync()
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.json') && !f.path.endsWith('/index.json'),
          );
      final provenance = jsonDecode(
        File('assets/original/provenance.json').readAsStringSync(),
      ) as Map;
      var count = 0;
      for (final file in files) {
        final data = Map<String, dynamic>.from(
          jsonDecode(file.readAsStringSync()) as Map,
        );
        final icon = FoliaIconData.fromJson(data);
        expect(icon.name, data['name'], reason: file.path);
        expect(icon.size, data['size'], reason: file.path);
        count++;
      }
      expect(count, provenance['lucide']['icons']);
    },
  );
  test(
    'original locales, plural forms, script selection and missing-key fallback',
    () async {
      final strings = await FoliaStrings.load('zh-Hant-HK');
      final original = jsonDecode(
        File('assets/original/locales/zh-TW.json').readAsStringSync(),
      ) as Map;
      expect(strings.language, 'zh-TW');
      expect(
        strings.t('libraryBravais.homeTitle'),
        original['libraryBravais']['homeTitle'],
      );
      expect(
        strings.t('libraryBravais.trackCount', args: {'count': 2}),
        (original['libraryBravais']['trackCount_other'] as String).replaceAll(
          '{{count}}',
          '2',
        ),
      );
      expect(normalizeSupportedLanguage('id-ID'), 'in');
      expect(normalizeSupportedLanguage('zh-CN'), 'zh-CN');
      expect(readAppLanguagePreference('id-ID'), 'system');
      expect(strings.t('missing.key', defaultValue: 'fallback'), 'fallback');
      final fallback = FoliaStrings(
        language: 'en',
        locale: {'x_one': '{{count}} item', 'x_other': '{{count}} items'},
        english: const {},
        chinese: {'zhOnly': '中文'},
      );
      expect(fallback.t('x', args: {'count': 1}), '1 item');
      expect(fallback.t('x', args: {'count': 3}), '3 items');
      expect(fallback.t('zhOnly'), '中文');
    },
  );
}

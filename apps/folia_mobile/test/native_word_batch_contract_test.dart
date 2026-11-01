import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/lyrics/native_word_segmentation.dart';

// Transport/cache ownership only: source fixture boundaries stand in for the device ICU reply, not for its still-required compatibility comparison.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('typed UTF-16 batches rebuild source text, cache without repeat calls and survive adapter disposal', () async {
    const channel = MethodChannel('test/native-icu');
    final source = jsonDecode(
      File('test/fixtures/lyric_reference.json').readAsStringSync(),
    ) as Map;
    final rows = source['semanticCases'] as List;
    final byText = {
      for (final row in rows)
        row['line']['fullText'] as String: row['plain'] as List,
    };
    var calls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      expect(call.method, 'segmentBatch');
      expect(call.arguments['locale'], 'en');
      final texts = call.arguments['texts'] as List;
      return {
        'icuVersion': 'fixture',
        'unicodeVersion': 'fixture',
        'defaultLocale': 'en',
        'locale': 'en',
        'segments': [
          for (final text in texts)
            Int32List.fromList([
              for (final segment in byText[text]!) ...[
                (segment['index'] as int) +
                    (segment['segment'] as String).length,
                segment['isWordLike'] == true ? 200 : 0,
              ],
            ]),
        ],
      };
    });
    final native = NativeWordSegmenter(localeTag: 'en', channel: channel);
    addTearDown(() {
      native.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    });
    final prepared = await native.prepareTexts(byText.keys);
    expect(calls, 1);
    for (final text in byText.keys) {
      expect(
        prepared.segment(text).map((s) => s.toJson()).toList(),
        byText[text],
      );
    }
    await native.prepareTexts(byText.keys.toList().reversed);
    expect(calls, 1);
    native.dispose();
    expect(prepared.segment(''), isEmpty);
    expect(
      prepared.segment(byText.keys.first).map((s) => s.segment).join(),
      byText.keys.first,
    );
    await expectLater(
      native.prepareTexts(byText.keys),
      throwsA(isA<WordPreparationCancelled>()),
    );
  });
}

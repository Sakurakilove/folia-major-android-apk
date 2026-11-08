import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/lyrics/native_word_segmentation.dart';
import 'package:folia_mobile/lyrics/native_word_text.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_poster_text.dart';

// Existing card case only: original word/title outputs and bounded preparation protocol. Mocked source ICU pairs do not certify Android's own ICU dictionaries or fonts.
Future<void> checkWallPosterText() async {
  final reference = jsonDecode(
        File('test/fixtures/poster_text_reference.json').readAsStringSync(),
      ),
      rows = <String, dynamic>{
        for (final row in reference['prepared']) row['title']: row,
      },
      methods = <String>[],
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('folia/poster-text-contract');
  final native = NativeWordSegmenter(
    localeTag: reference['locale'],
    channel: channel,
  );
  messenger.setMockMethodCallHandler(channel, (call) async {
    methods.add(call.method);
    expect(call.arguments['locale'], reference['locale']);
    final texts = (call.arguments['texts'] as List)
        .map(NativeWordText.decode)
        .toList();
    if (call.method == 'segmentBatch') {
      for (final text in texts) {
        if (!rows.containsKey(text)) {
          throw StateError('Unprepared source reference: ${jsonEncode(text)}');
        }
      }
    }
    expect(texts.length, lessThanOrEqualTo(128));
    return {
      'icuVersion': reference['icu'],
      'unicodeVersion': reference['unicode'],
      'defaultLocale': reference['locale'],
      if (call.method == 'segmentBatch')
        'segments': [
          for (final text in texts)
            Int32List.fromList(<int>[
              for (final p in rows[text]['parts']) ...[
                (p['index'] as int) + (p['text'] as String).length,
                p['wordLike'] == true ? 200 : 0,
              ],
            ]),
        ]
      else
        'lowercase': [
          for (final text in texts)
            NativeWordText.encode(reference['lowercase'][text] as String),
        ],
    };
  });
  try {
    final prepared = await PreparedBravaisPosterText.prepare(native, [
      for (final row in reference['cases']) row['title'] as String,
      for (final group in reference['groups'])
        ...List<String>.from(group['titles']),
    ]);
    for (final row in reference['cases']) {
      final title = row['title'] as String, words = prepared.words(title);
      expect([
        for (final word in words) {'text': word.text, 'hero': word.hero},
      ], row['words']);
      expect(bravaisAlbumGhost(title, words), row['ghost']);
      expect(bravaisPosterNameColumns(title), row['nameColumns']);
      expect(bravaisAlbumTitleColumns(title), row['albumColumns']);
    }
    for (final group in reference['groups']) {
      expect(
        prepared.scraps(List<String>.from(group['titles'])),
        group['expected'],
      );
    }
    expect(methods, ['segmentBatch', 'lowerBatch']);
  } finally {
    native.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  }
}

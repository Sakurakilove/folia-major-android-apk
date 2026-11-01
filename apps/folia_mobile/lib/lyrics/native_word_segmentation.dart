import 'package:flutter/services.dart';

import 'word_segmentation.dart';

part 'native_word_segmentation_batch.dart';

// Android ICU is called in bounded document-preparation batches; layout reads immutable UTF-16 pieces synchronously without any channel call.
class NativeIcuInfo {
  NativeIcuInfo.fromMap(Map data)
    : icuVersion = data['icuVersion'] as String,
      unicodeVersion = data['unicodeVersion'] as String,
      defaultLocale = data['defaultLocale'] as String;
  final String icuVersion, unicodeVersion, defaultLocale;
}

class PreparedPlainSegmentation {
  PreparedPlainSegmentation(
    Map<String, List<LyricWordSegment>> parts,
    this.info,
  ) : _parts = Map.unmodifiable(parts);
  final Map<String, List<LyricWordSegment>> _parts;
  final NativeIcuInfo? info;
  List<LyricWordSegment> segment(String text) => text.isEmpty
      ? const []
      : _parts[text] ??
            (throw StateError('Text was not prepared for this document'));
}

class NativeWordSegmenter {
  NativeWordSegmenter({required this.localeTag, MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;
  static const _defaultChannel = MethodChannel(
    'top.izuna.folia/word-segmentation',
  );
  final String localeTag;
  final MethodChannel _channel;
  final _cache = <String, List<LyricWordSegment>>{};
  int _cacheUnits = 0;
  Future<void> _tail = Future.value();
  bool _closed = false;
  NativeIcuInfo? _info;
  static Future<NativeIcuInfo> readInfo({
    MethodChannel channel = _defaultChannel,
  }) async =>
      NativeIcuInfo.fromMap((await channel.invokeMapMethod('getInfo'))!);

  Future<PreparedPlainSegmentation> prepareTexts(
    Iterable<String> texts, {
    bool Function()? stillWanted,
  }) async {
    final parts = <String, List<LyricWordSegment>>{}, missing = <String>[];
    void check() {
      if (_closed || (stillWanted != null && !stillWanted())) {
        throw const WordPreparationCancelled();
      }
    }

    check();
    for (final text in texts.toSet()) {
      final cached = _cache[text];
      if (text.isEmpty) {
        parts[text] = const [];
      } else if (cached != null) {
        parts[text] = cached;
      } else {
        missing.add(text);
      }
    }
    for (final batch in _wordBatches(missing)) {
      check();
      final response = await _request(batch);
      check();
      final records = response['segments'];
      if (records is! List || records.length != batch.length) {
        throw const FormatException('Invalid native word batch');
      }
      _info = NativeIcuInfo.fromMap(response);
      for (var i = 0; i < batch.length; i++) {
        final segments = _decodeWordPairs(batch[i], records[i]);
        parts[batch[i]] = segments;
        _remember(batch[i], segments);
      }
    }
    return PreparedPlainSegmentation(parts, _info);
  }

  Future<Map<String, dynamic>> _request(List<String> texts) {
    final task = _tail.then((_) async {
      if (_closed) throw const WordPreparationCancelled();
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'segmentBatch',
        {'texts': texts, 'locale': localeTag},
      );
      if (_closed) throw const WordPreparationCancelled();
      if (response == null) {
        throw const FormatException('Missing native word batch');
      }
      return response;
    });
    _tail = task.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return task;
  }

  void _remember(String text, List<LyricWordSegment> segments) {
    if (text.length > 262144) return; // The complete oversized result still belongs to its prepared document.
    if (_cache.containsKey(text)) return;
    while (_cache.isNotEmpty &&
        (_cache.length >= 512 || _cacheUnits + text.length > 262144)) {
      final key = _cache.keys.first;
      _cacheUnits -= key.length;
      _cache.remove(key);
    }
    _cache[text] = segments;
    _cacheUnits += text.length;
  }

  void dispose() {
    _closed = true;
    _cache.clear();
    _cacheUnits = 0;
  }
}

class WordPreparationCancelled implements Exception {
  const WordPreparationCancelled();
}

part of 'native_word_segmentation.dart';

// Poster scrap deduplication uses standalone toLocaleLowerCase candidates. Prepare them once in the same bounded ICU worker queue, never during layout or animation.
extension NativeWordCase on NativeWordSegmenter {
  Future<Map<String, String>> lowercaseTexts(
    Iterable<String> texts, {
    bool Function()? stillWanted,
  }) async {
    final values = <String, String>{};
    for (final batch in _wordBatches(texts.toSet().toList())) {
      void check() {
        if (_closed || (stillWanted != null && !stillWanted())) {
          throw const WordPreparationCancelled();
        }
      }

      check();
      final response = await _request(batch, method: 'lowerBatch');
      check();
      final lower = response['lowercase'];
      if (lower is! List || lower.length != batch.length) {
        throw const FormatException('Invalid native lowercase batch');
      }
      for (var i = 0; i < batch.length; i++) {
        values[batch[i]] = NativeWordText.decode(lower[i]);
      }
    }
    if (_closed || (stillWanted != null && !stillWanted())) {
      throw const WordPreparationCancelled();
    }
    return Map.unmodifiable(values);
  }
}

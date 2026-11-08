import '../../../lyrics/native_word_segmentation.dart';
import '../../../lyrics/word_segmentation.dart';
import '../../../rendering/js_text.dart';

// Original poster title/scrap rules operate on Unicode code points, not graphemes. ICU document preparation supplies immutable segmentation and locale folds before native layout.
typedef BravaisHeroWord = ({String text, bool hero});
List<BravaisHeroWord> splitBravaisHeroWord(
  String title,
  PlainWordSegmenter segment,
) {
  final parts = segment(title);
  var hero = -1, length = 0, words = 0;
  for (var i = 0; i < parts.length; i++) {
    if (!parts[i].isWordLike) continue;
    words++;
    final size = parts[i].segment.runes.length;
    if (size > length) {
      hero = i;
      length = size;
    }
  }
  if (words < 2) hero = -1;
  return List.unmodifiable([
    for (var i = 0; i < parts.length; i++)
      (text: parts[i].segment, hero: i == hero),
  ]);
}

List<String> bravaisPosterScrapWords(
  Iterable<String> titles,
  PlainWordSegmenter segment,
  String Function(String) lowercase,
) {
  final used = <String>{}, result = <String>[];
  for (final raw in titles) {
    final title = jsTrim(raw),
        words = segment(title)
            .where((p) => p.isWordLike)
            .map((p) => p.segment)
            .toList(),
        ordered = [
          for (var i = 0; i < words.length; i++) (text: words[i], order: i),
        ];
    // Dart sort need not be stable. Preserve source order for equal lengths.
    ordered.sort((a, b) {
      final n = b.text.runes.length.compareTo(a.text.runes.length);
      return n == 0 ? a.order.compareTo(b.order) : n;
    });
    for (final candidate in [
      if (words.length >= 2) ...ordered.map((p) => p.text),
      String.fromCharCodes(title.runes.take(2)),
    ]) {
      if (candidate.isEmpty) continue;
      final folded = lowercase(candidate);
      if (used.add(folded)) {
        result.add(candidate);
        break;
      }
    }
    if (result.length == 2) break;
  }
  return List.unmodifiable(result);
}

final _wide = RegExp(
      r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
      unicode: true,
    ),
    _spaces = RegExp('[$jsWhitespacePattern]+', unicode: true);
double _columns(String value) => value.runes.fold(
  0.0,
  (sum, rune) => sum + (_wide.hasMatch(String.fromCharCode(rune)) ? 1.02 : .62),
);
double bravaisPosterNameColumns(String value) {
  final characters = value.runes.toList(),
      wide = characters
          .where((r) => _wide.hasMatch(String.fromCharCode(r)))
          .length;
  return (wide * 1.02 + (characters.length - wide) * .62).clamp(
    2.0,
    double.infinity,
  );
}

double bravaisAlbumTitleColumns(String value) {
  var columns = (_columns(value) / 3).clamp(2.0, double.infinity);
  for (final word in value.split(_spaces)) {
    if (!_wide.hasMatch(word)) {
      columns = columns < _columns(word) ? _columns(word) : columns;
    }
  }
  return columns;
}

String bravaisAlbumGhost(String title, List<BravaisHeroWord> words) {
  final hero = words.where((p) => p.hero).firstOrNull?.text ?? title;
  return hero.isEmpty ? '' : String.fromCharCode(hero.runes.last);
}

class PreparedBravaisPosterText {
  PreparedBravaisPosterText._(this.parts, this.lowercase, this.localeTag);
  final PreparedPlainSegmentation parts;
  final Map<String, String> lowercase;
  final String localeTag;
  static Future<PreparedBravaisPosterText> prepare(
    NativeWordSegmenter native,
    Iterable<String> titles, {
    bool Function()? stillWanted,
  }) async {
    final texts = titles.toSet(),
        parts = await native.prepareTexts({
          ...texts,
          ...texts.map(jsTrim),
        }, stillWanted: stillWanted),
        candidates = <String>{};
    for (final title in texts.map(jsTrim)) {
      candidates.addAll(
        parts.segment(title).where((p) => p.isWordLike).map((p) => p.segment),
      );
      candidates.add(String.fromCharCodes(title.runes.take(2)));
    }
    return PreparedBravaisPosterText._(
      parts,
      await native.lowercaseTexts(candidates, stillWanted: stillWanted),
      native.localeTag,
    );
  }

  List<BravaisHeroWord> words(String title) =>
      splitBravaisHeroWord(title, parts.segment);
  List<String> scraps(Iterable<String> titles) => bravaisPosterScrapWords(
    titles,
    parts.segment,
    (text) =>
        lowercase[text] ??
        (throw StateError('Poster candidate was not prepared')),
  );
}

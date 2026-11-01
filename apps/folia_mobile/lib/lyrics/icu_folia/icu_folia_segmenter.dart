// Original ICU script-run dispatch, Chinese trailing particles and alphabetic hyphen join; plain ICU pieces are prepared before this pure pipeline runs.
abstract interface class IcuFoliaCutters {
  List<String> cutChinese(String text);
  List<String> parseJapanese(String text);
}

class IcuFoliaSegmenter {
  IcuFoliaSegmenter.fromJson(Map lexicon)
    : trailingParticles = Set<String>.from(
        lexicon['trailingParticles'] as List,
      ),
      nonHosts = Set<String>.from(lexicon['nonHosts'] as List);
  final Set<String> trailingParticles, nonHosts;
  static final _cj = RegExp(
        r'^[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}ー々〆〇]+$',
        unicode: true,
      ),
      _kana = RegExp(
        r'[\p{Script=Hiragana}\p{Script=Katakana}ー]',
        unicode: true,
      ),
      _alphabetic = RegExp(r'^[\p{L}\p{M}\p{N}]+$', unicode: true),
      _notAlphabetic = RegExp(
        r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]',
        unicode: true,
      ),
      _hyphen = RegExp(r'^[-‐‑]$'),
      _hyphens = RegExp(r'[-‐‑]');
  bool _word(String text) =>
      _alphabetic.hasMatch(text) && !_notAlphabetic.hasMatch(text);
  static bool _rebuilds(List<String> words, String text) =>
      words.isNotEmpty && words.join() == text;
  List<String> _cutRun(
    String text,
    List<String> original,
    IcuFoliaCutters? engines,
  ) {
    if (engines == null) return original;
    if (_kana.hasMatch(text)) {
      final words = engines.parseJapanese(text);
      return _rebuilds(words, text) ? words : original;
    }
    final words = engines.cutChinese(text);
    if (!_rebuilds(words, text)) return original;
    final out = <String>[];
    for (final word in words) {
      if (out.isNotEmpty &&
          trailingParticles.contains(word) &&
          !nonHosts.contains(out.last)) {
        out[out.length - 1] += word;
      } else {
        out.add(word);
      }
    }
    return out;
  }

  List<String> segment(
    String text,
    List<String> icuPieces, {
    IcuFoliaCutters? engines,
  }) {
    if (text.isEmpty) return [];
    if (icuPieces.join() != text) {
      throw const FormatException(
        'Prepared ICU pieces do not rebuild the source',
      );
    }
    final out = <String>[];
    for (var i = 0; i < icuPieces.length;) {
      if (!_cj.hasMatch(icuPieces[i])) {
        out.add(icuPieces[i++]);
        continue;
      }
      final run = <String>[];
      while (i < icuPieces.length && _cj.hasMatch(icuPieces[i])) {
        run.add(icuPieces[i++]);
      }
      out.addAll(_cutRun(run.join(), run, engines));
    }
    final joined = <String>[];
    for (var i = 0; i < out.length; i++) {
      final piece = out[i], next = i + 1 < out.length ? out[i + 1] : null;
      if (_hyphen.hasMatch(piece) &&
          joined.isNotEmpty &&
          next != null &&
          _word(joined.last.split(_hyphens).last) &&
          _word(next)) {
        joined[joined.length - 1] += piece + next;
        i++;
      } else {
        joined.add(piece);
      }
    }
    return joined;
  }
}

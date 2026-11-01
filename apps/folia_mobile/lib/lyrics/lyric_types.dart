import 'render_hints.dart';

// Normalized src/types.ts contracts, including parser metadata; unknown fields survive round trips.
typedef LyricJson = Map<String, dynamic>;

List<T> _records<T>(dynamic value, T Function(LyricJson) decode) =>
    value is List
    ? List<T>.unmodifiable(
        value.map((item) => decode(Map<String, dynamic>.from(item as Map))),
      )
    : List<T>.empty(growable: false);

class LyricRuby {
  LyricRuby.fromJson(LyricJson data)
    : text = data['text'] as String,
      start = (data['startTime'] as num).toDouble(),
      end = (data['endTime'] as num).toDouble(),
      source = Map.unmodifiable(data);
  final String text;
  final double start, end;
  final LyricJson source;
  LyricJson toJson() => Map.of(source);
}

class LyricSyllable {
  LyricSyllable.fromJson(LyricJson data)
    : text = data['text'] as String,
      start = (data['startTime'] as num).toDouble(),
      end = (data['endTime'] as num).toDouble(),
      endsWithSpace = data['endsWithSpace'] as bool?,
      obscene = data['obscene'] as bool?,
      emptyBeat = (data['emptyBeat'] as num?)?.toDouble(),
      ruby = _records(data['ruby'], LyricRuby.fromJson),
      source = Map.unmodifiable(data);
  final String text;
  final double start, end;
  final bool? endsWithSpace, obscene;
  final double? emptyBeat;
  final List<LyricRuby> ruby;
  final LyricJson source;
  LyricJson toJson() => Map.of(source);
}

class LyricWord {
  const LyricWord(
    this.text,
    this.start,
    this.end, {
    this.syllables = const [],
    this.source = const {},
  });
  factory LyricWord.fromJson(LyricJson data) => LyricWord(
    data['text'] as String,
    (data['startTime'] as num).toDouble(),
    (data['endTime'] as num).toDouble(),
    syllables: _records(data['syllables'], LyricSyllable.fromJson),
    source: Map.unmodifiable(data),
  );
  final String text;
  final double start, end;
  final List<LyricSyllable> syllables;
  final LyricJson source;
  LyricJson toJson() => {
    ...source,
    'text': text,
    'startTime': start,
    'endTime': end,
    if (syllables.isNotEmpty)
      'syllables': syllables.map((s) => s.toJson()).toList(),
  };
}

class LyricAlternateText {
  LyricAlternateText.fromJson(LyricJson data)
    : role = data['role'] as String,
      text = data['text'] as String,
      language = data['language'] as String?,
      syllables = _records(data['syllables'], LyricSyllable.fromJson),
      source = Map.unmodifiable(data);
  final String role, text;
  final String? language;
  final List<LyricSyllable> syllables;
  final LyricJson source;
  LyricJson toJson() => Map.of(source);
}

class LyricBackgroundVocal {
  LyricBackgroundVocal.fromJson(LyricJson data)
    : text = data['text'] as String,
      start = (data['startTime'] as num).toDouble(),
      end = (data['endTime'] as num).toDouble(),
      words = _records(data['words'], LyricWord.fromJson),
      agentId = data['agentId'] as String?,
      translation = data['translation'] as String?,
      romanization = data['romanization'] as String?,
      alternateTexts = _records(
        data['alternateTexts'],
        LyricAlternateText.fromJson,
      ),
      source = Map.unmodifiable(data);
  final String text;
  final double start, end;
  final List<LyricWord> words;
  final String? agentId, translation, romanization;
  final List<LyricAlternateText> alternateTexts;
  final LyricJson source;
  LyricJson toJson() => Map.of(source);
}

class LyricLine {
  const LyricLine(
    this.text,
    this.start,
    this.end,
    this.words, {
    this.translation,
    this.romanization,
    this.id,
    this.agentId,
    this.songPart,
    this.blockIndex,
    this.alternateTexts = const [],
    this.backgroundVocal,
    this.backgroundVocals = const [],
    this.renderHints,
    this.isChorus = false,
    this.chorusEffect,
    this.wordSegments,
    this.autoWordSegments,
    this.source = const {},
  });
  factory LyricLine.fromJson(LyricJson data) => LyricLine(
    data['fullText'] as String,
    (data['startTime'] as num).toDouble(),
    (data['endTime'] as num).toDouble(),
    _records(data['words'], LyricWord.fromJson),
    translation: data['translation'] as String?,
    romanization: data['romanization'] as String?,
    id: data['id'] as String?,
    agentId: data['agentId'] as String?,
    songPart: data['songPart'] as String?,
    blockIndex: (data['blockIndex'] as num?)?.toInt(),
    alternateTexts: _records(
      data['alternateTexts'],
      LyricAlternateText.fromJson,
    ),
    backgroundVocal: data['backgroundVocal'] is Map
        ? LyricBackgroundVocal.fromJson(
            Map<String, dynamic>.from(data['backgroundVocal'] as Map),
          )
        : null,
    backgroundVocals: _records(
      data['backgroundVocals'],
      LyricBackgroundVocal.fromJson,
    ),
    renderHints: data['renderHints'] is Map
        ? LineRenderHints.fromJson(
            Map<String, dynamic>.from(data['renderHints'] as Map),
          )
        : null,
    isChorus: data['isChorus'] == true,
    chorusEffect: data['chorusEffect'] as String?,
    wordSegments: data['wordSegments'] is List
        ? List<String>.unmodifiable(data['wordSegments'] as List)
        : null,
    autoWordSegments: data['autoWordSegments'] is List
        ? List<String>.unmodifiable(data['autoWordSegments'] as List)
        : null,
    source: Map.unmodifiable(data),
  );
  final String text;
  final double start, end;
  final List<LyricWord> words;
  final String? translation, romanization, id, agentId, songPart, chorusEffect;
  final int? blockIndex;
  final List<LyricAlternateText> alternateTexts;
  final LyricBackgroundVocal? backgroundVocal;
  final List<LyricBackgroundVocal> backgroundVocals;
  final LineRenderHints? renderHints;
  final bool isChorus;
  final List<String>? wordSegments, autoWordSegments;
  final LyricJson source;
  LineRenderHints get hints =>
      renderHints ??
      buildLineRenderHints(
        start,
        end,
        lastWordEnd: words.isEmpty ? null : words.last.end,
      );
  LyricJson toJson() => {
    ...source,
    'fullText': text,
    'startTime': start,
    'endTime': end,
    'words': words.map((w) => w.toJson()).toList(),
    if (translation != null) 'translation': translation,
    if (romanization != null) 'romanization': romanization,
    if (id != null) 'id': id,
    if (agentId != null) 'agentId': agentId,
    if (songPart != null) 'songPart': songPart,
    if (blockIndex != null) 'blockIndex': blockIndex,
    if (alternateTexts.isNotEmpty)
      'alternateTexts': alternateTexts.map((a) => a.toJson()).toList(),
    if (backgroundVocal != null) 'backgroundVocal': backgroundVocal!.toJson(),
    if (backgroundVocals.isNotEmpty)
      'backgroundVocals': backgroundVocals.map((b) => b.toJson()).toList(),
    if (renderHints != null) 'renderHints': renderHints!.toJson(),
    if (isChorus) 'isChorus': true,
    if (chorusEffect != null) 'chorusEffect': chorusEffect,
    if (wordSegments != null) 'wordSegments': wordSegments,
    if (autoWordSegments != null) 'autoWordSegments': autoWordSegments,
  };
}

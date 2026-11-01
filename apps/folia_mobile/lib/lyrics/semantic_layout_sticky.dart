part of 'semantic_layout.dart';

// Exact punctuation/contraction passes from cjkSemanticLayout.ts; clones prevent caller-owned parser units being mutated.
final _apostropheOnly = RegExp(r"^['’]\s*$"),
    _suffix = RegExp(r'^(s|t|m|d|ll|re|ve|em)\s*$', caseSensitive: false),
    _directContraction = RegExp(
      r"^['’](s|t|m|d|ll|re|ve|em)\s*$",
      caseSensitive: false,
    ),
    _trailingApostrophe = RegExp(r"['’]\s*$"),
    _wordChar = RegExp(r'[\p{L}\p{N}]$', unicode: true),
    _inlineContraction = RegExp(
      r"[\p{L}\p{N}]+['’](s|t|m|d|ll|re|ve|em)",
      unicode: true,
      caseSensitive: false,
    ),
    _trailingPunctuation = RegExp(
      r'''^[,.;:!?，。！？、：；）】》」』〉〕］)}\]"'’”’]+$''',
      unicode: true,
    ),
    _trimStart = RegExp(r'^\s+', unicode: true),
    _trimEnd = RegExp(r'\s+$', unicode: true);
String _trim(String text) =>
    text.replaceFirst(_trimStart, '').replaceFirst(_trimEnd, '');
bool _canAttach(String text) =>
    _wordChar.hasMatch(text.replaceFirst(_trimEnd, ''));
void _append(LyricLayoutUnit target, LyricLayoutUnit unit) {
  target.text += unit.text;
  target.words.addAll(unit.words);
  target.end = unit.end;
  target.isSticky = true;
}

List<LyricLayoutUnit> applyStickyPunctuationLayoutUnits(
  List<LyricLayoutUnit> units,
) {
  final merged = <LyricLayoutUnit>[];
  for (var index = 0; index < units.length; index++) {
    final current = units[index], previous = merged.lastOrNull;
    if (previous == null) {
      merged.add(current.clone());
      continue;
    }
    final text = _trim(current.text),
        next = index + 1 < units.length ? units[index + 1] : null;
    if (_apostropheOnly.hasMatch(text) &&
        next != null &&
        _canAttach(previous.text) &&
        _suffix.hasMatch(_trim(next.text))) {
      _append(previous, current);
      _append(previous, next);
      index++;
      continue;
    }
    if (_directContraction.hasMatch(text) && _canAttach(previous.text) ||
        _suffix.hasMatch(text) &&
            _trailingApostrophe.hasMatch(
              previous.text.replaceFirst(_trimEnd, ''),
            ) ||
        _trailingPunctuation.hasMatch(text) && _canAttach(previous.text)) {
      _append(previous, current);
      continue;
    }
    merged.add(current.clone());
  }
  for (final unit in merged) {
    final trailing =
        unit.words.length > 1 &&
        _trailingPunctuation.hasMatch(_trim(unit.words.last.text));
    final contraction =
        unit.words.length > 1 &&
        !unit.isSemantic &&
        _inlineContraction.hasMatch(unit.text);
    if (trailing || contraction) unit.isSticky = true;
  }
  return merged;
}

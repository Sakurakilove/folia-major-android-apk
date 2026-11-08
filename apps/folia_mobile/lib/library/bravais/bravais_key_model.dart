import '../wall/wall_navigation.dart';

// Original non-printable wall shortcuts and single-level Escape priority. Space and typing remain owned by the global player/command/filter handlers.
class BravaisKeyInput {
  const BravaisKeyInput(
    this.key, {
    this.shiftKey = false,
    this.altKey = false,
    this.ctrlKey = false,
    this.metaKey = false,
    this.repeat = false,
  });
  final String key;
  final bool shiftKey, altKey, ctrlKey, metaKey, repeat;
}

enum BravaisKeyActionType {
  move('move'),
  enter('enter'),
  enqueue('enqueue'),
  openAlbum('open-album'),
  openArtist('open-artist'),
  escape('escape'),
  first('first'),
  last('last'),
  page('page'),
  tab('tab'),
  cycleTab('cycle-tab'),
  openSearch('open-search'),
  batchToggle('batch-toggle'),
  batchSelectAll('batch-select-all'),
  batchPlay('batch-play'),
  batchRemove('batch-remove');

  const BravaisKeyActionType(this.value);
  final String value;
}

class BravaisKeyAction {
  const BravaisKeyAction(
    this.type, {
    this.direction,
    this.amount,
    this.backwards = false,
    this.enqueue = false,
  });
  final BravaisKeyActionType type;
  final WallDirection? direction;
  final int? amount;
  final bool backwards, enqueue;
  Map<String, Object?> toJson() => {
    'type': type.value,
    if (type == BravaisKeyActionType.move) 'direction': direction!.name,
    if (type == BravaisKeyActionType.page) 'direction': amount,
    if (type == BravaisKeyActionType.cycleTab) 'delta': amount,
    if (type == BravaisKeyActionType.tab) 'backwards': backwards,
    if (type == BravaisKeyActionType.batchPlay) 'enqueue': enqueue,
  };
}

BravaisKeyAction? resolveBravaisKey(BravaisKeyInput input) {
  if (input.ctrlKey || input.metaKey) return null;
  if (input.key == 'Enter') {
    if (input.repeat) return null;
    if (input.altKey) {
      return BravaisKeyAction(
        input.shiftKey
            ? BravaisKeyActionType.openArtist
            : BravaisKeyActionType.openAlbum,
      );
    }
    return BravaisKeyAction(
      input.shiftKey
          ? BravaisKeyActionType.enqueue
          : BravaisKeyActionType.enter,
    );
  }
  if (input.altKey) return null;
  if (input.key == 'Escape') {
    return input.repeat
        ? null
        : const BravaisKeyAction(BravaisKeyActionType.escape);
  }
  if (input.key == 'Tab') {
    return BravaisKeyAction(
      BravaisKeyActionType.tab,
      backwards: input.shiftKey,
    );
  }
  if (input.shiftKey) return null;
  final direction = switch (input.key) {
    'ArrowUp' => WallDirection.up,
    'ArrowDown' => WallDirection.down,
    'ArrowLeft' => WallDirection.left,
    'ArrowRight' => WallDirection.right,
    _ => null,
  };
  if (direction != null) {
    return BravaisKeyAction(BravaisKeyActionType.move, direction: direction);
  }
  return switch (input.key) {
    'Home' => const BravaisKeyAction(BravaisKeyActionType.first),
    'End' => const BravaisKeyAction(BravaisKeyActionType.last),
    'PageDown' => const BravaisKeyAction(BravaisKeyActionType.page, amount: 1),
    'PageUp' => const BravaisKeyAction(BravaisKeyActionType.page, amount: -1),
    _ => null,
  };
}

enum BravaisEscapeStep {
  form('form'),
  focusCard('focus-card'),
  keyboardFocus('keyboard-focus'),
  panel('panel'),
  view('view'),
  query('query'),
  back('back');

  const BravaisEscapeStep(this.value);
  final String value;
}

BravaisEscapeStep? resolveBravaisEscapeStep({
  bool hasForm = false,
  required bool hasFocusCard,
  required bool hasKeyboardFocus,
  bool hasPanel = false,
  bool hasViewMode = false,
  bool hasQuery = false,
  required bool canGoBack,
}) {
  if (hasForm) return BravaisEscapeStep.form;
  if (hasFocusCard) return BravaisEscapeStep.focusCard;
  if (hasKeyboardFocus) return BravaisEscapeStep.keyboardFocus;
  if (hasPanel) return BravaisEscapeStep.panel;
  if (hasViewMode) return BravaisEscapeStep.view;
  if (hasQuery) return BravaisEscapeStep.query;
  return canGoBack ? BravaisEscapeStep.back : null;
}

enum BravaisTypingKey { char, ime }

BravaisTypingKey? resolveBravaisTypingKey(
  BravaisKeyInput input, {
  Iterable<String> reserved = const [],
}) {
  if (input.altKey || input.ctrlKey || input.metaKey) return null;
  if (input.key == 'Process' || input.key == 'Unidentified') {
    return BravaisTypingKey.ime;
  }
  if (input.key.runes.length != 1 ||
      input.key == ' ' ||
      reserved.contains(input.key)) {
    return null;
  }
  return BravaisTypingKey.char;
}

import 'bravais_key_model.dart';

BravaisKeyAction? resolveBravaisWallKey(BravaisKeyInput input) =>
    resolveBravaisKey(input) ?? resolveBravaisHomeKey(input);

// Capability checks remain in the actual home action handler. Resolving a shortcut alone must not consume Ctrl+A or turn a directory Enter into navigation while batch mode owns it.
BravaisKeyAction? resolveBravaisHomeKey(BravaisKeyInput input) {
  if (input.repeat || input.altKey) return null;
  final command = input.ctrlKey || input.metaKey;
  if (input.key == 'F6' && !command) {
    return BravaisKeyAction(
      BravaisKeyActionType.cycleTab,
      amount: input.shiftKey ? -1 : 1,
    );
  }
  if (command) {
    if (input.key == 'Enter') {
      return BravaisKeyAction(
        BravaisKeyActionType.batchPlay,
        enqueue: input.shiftKey,
      );
    }
    if (!input.shiftKey && (input.key == 'a' || input.key == 'A')) {
      return const BravaisKeyAction(BravaisKeyActionType.batchSelectAll);
    }
    return null;
  }
  if (input.key == '/') {
    return const BravaisKeyAction(BravaisKeyActionType.openSearch);
  }
  if (input.shiftKey) return null;
  if (input.key == 'Insert') {
    return const BravaisKeyAction(BravaisKeyActionType.batchToggle);
  }
  if (input.key == 'Delete') {
    return const BravaisKeyAction(BravaisKeyActionType.batchRemove);
  }
  return null;
}

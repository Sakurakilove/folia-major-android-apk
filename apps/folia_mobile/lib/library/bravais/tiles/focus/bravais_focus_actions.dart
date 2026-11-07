// The original surface supplies capabilities and actions by slot key; display data alone cannot invent provider operations.
class BravaisEntryMenuItem {
  const BravaisEntryMenuItem(this.id, this.label, {this.danger = false});
  final String id, label;
  final bool danger;
}

class BravaisCardActions {
  const BravaisCardActions({
    required this.activate,
    required this.play,
    required this.enqueue,
    required this.canOpenAlbum,
    required this.openAlbum,
    required this.canOpenArtist,
    required this.openArtist,
    required this.menuFor,
    required this.runMenu,
    required this.hover,
    required this.togglesCurrent,
    this.enterPlayback,
    this.toggleHidden,
  });
  final void Function(String slot) activate, play, enqueue, openAlbum;
  final bool Function(String key) canOpenAlbum;
  final bool Function(String key, int index) canOpenArtist;
  final void Function(String slot, int index) openArtist;
  final List<BravaisEntryMenuItem> Function(String key) menuFor;
  final void Function(String slot, String actionId) runMenu;
  final void Function(String? slot) hover;
  final bool togglesCurrent;
  final void Function()? enterPlayback;
  final void Function(String slot)? toggleHidden;
}

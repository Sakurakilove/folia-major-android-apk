// Discrete focus/list state; camera positions and reflow samples never enter this object or rebuild its consumers every frame.
class BravaisWallSelection {
  const BravaisWallSelection({
    this.expandedSlotKey,
    this.focusedSlotKey,
    this.linkedKey,
  });
  final String? expandedSlotKey, focusedSlotKey, linkedKey;
  @override
  bool operator ==(Object other) =>
      other is BravaisWallSelection &&
      expandedSlotKey == other.expandedSlotKey &&
      focusedSlotKey == other.focusedSlotKey &&
      linkedKey == other.linkedKey;
  @override
  int get hashCode => Object.hash(expandedSlotKey, focusedSlotKey, linkedKey);
}

import 'package:flutter/foundation.dart';

import 'bravais_cover_flights.dart';
import 'bravais_cover_memory.dart';
import 'bravais_cover_quad.dart';

// One actual wall owns only its mounted tile handles. Capturing a return tile preserves that handle through slot reuse; an old unmount must not unregister its replacement.
class BravaisCoverTileBinding {
  const BravaisCoverTileBinding({required this.connected, required this.tile});
  final bool Function() connected;
  final BravaisCoverReturnTile tile;
}

class BravaisCoverTiles {
  BravaisCoverTiles(this.memory);
  final BravaisCoverMemory memory;
  final _tiles = <String, List<BravaisCoverTileBinding>>{};
  bool _closed = false;
  VoidCallback register(String slot, BravaisCoverTileBinding binding) {
    if (_closed) throw StateError('Cover tile registry is closed');
    final owners = _tiles.putIfAbsent(slot, () => []);
    owners.add(binding);
    var released = false;
    return () {
      if (released) return;
      released = true;
      owners.remove(binding);
      if (owners.isEmpty && identical(_tiles[slot], owners)) {
        _tiles.remove(slot);
      }
    };
  }

  BravaisCoverReturnTile? find(String slot) {
    for (final owner in _tiles[slot] ?? const <BravaisCoverTileBinding>[]) {
      if (owner.connected()) return owner.tile;
    }
    return null;
  }

  void note(String slot, String card, String? coverUrl) => memory.note(
    slotKey: slot,
    cardKey: card,
    coverUrl: coverUrl,
    quad: find(slot)?.measure(),
  );

  // The callback is also useful before an actual measured tile has mounted.
  BravaisCoverQuad? measure(String slot) => find(slot)?.measure();
  void dispose() {
    _closed = true;
    _tiles.clear();
  }
}

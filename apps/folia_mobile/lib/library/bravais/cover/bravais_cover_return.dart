part of 'bravais_cover_flights.dart';

// Capture the actual retained tile handle when it appears, then keep that handle through the flight. A reused slot on another wall must not have its incoming animation finished.
class BravaisCoverReturnTile {
  const BravaisCoverReturnTile({
    required this.measure,
    required this.cardKey,
    required this.finishFiniteEntrances,
  });
  final BravaisCoverQuad? Function() measure;
  final String? Function() cardKey;
  final VoidCallback finishFiniteEntrances;
}

extension BravaisCoverReturn on BravaisCoverFlights {
  void back({
    required bool reducedMotion,
    required bool Function() coverConnected,
    required BravaisCoverQuad from,
    required BravaisCoverShadow shadow,
    required String cardKey,
    required String coverUrl,
    required BravaisCoverReturnTile? Function() findTile,
  }) {
    if (_closed || reducedMotion) return;
    final start = nowMs();
    _returns.add(
      _CoverReturn((now) {
        // Source schedules the first check on the next frame and aborts if the
        // original cover is still connected (including an effect rerun).
        if (coverConnected()) return true;
        final tile = findTile();
        if (tile != null) {
          fly(
            url: coverUrl,
            from: from,
            target: tile.measure,
            duration: 560,
            shadowFrom: shadow,
            shadowTo: (_) => BravaisCoverShadow.none,
            landing: BravaisCoverLanding.fade,
            ready: () => tile.cardKey() == cardKey,
            onDone: () {
              if (tile.cardKey() == cardKey) tile.finishFiniteEntrances();
            },
          );
          return true;
        }
        return now - start >= 900;
      }),
    );
    _sync();
  }
}

class _CoverReturn {
  const _CoverReturn(this.step);
  final bool Function(double) step;
}

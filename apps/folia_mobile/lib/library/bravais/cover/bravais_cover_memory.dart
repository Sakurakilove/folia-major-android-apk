import '../../../artwork/cover_url.dart';
import 'bravais_cover_quad.dart';

// The wall/poster share one session memory. Taking a source or parked return consumes it even when expired, mismatched or motion-reduced.
class BravaisCoverSource {
  const BravaisCoverSource({
    required this.cardKey,
    required this.slotKey,
    required this.coverUrl,
    required this.quad,
    required this.at,
  });
  final String cardKey, slotKey, coverUrl;
  final BravaisCoverQuad quad;
  final double at;
}

typedef BravaisCoverBackOrigin = ({String slotKey, String cardKey});

class BravaisCoverMemory {
  BravaisCoverMemory({required this.urls, required this.nowMs});
  final CoverUrlPolicy urls;
  final double Function() nowMs;
  BravaisCoverSource? _source;
  ({String layerKey, BravaisCoverBackOrigin origin})? _parked;
  void note({
    required String cardKey,
    required String slotKey,
    required String? coverUrl,
    required BravaisCoverQuad? quad,
  }) {
    if (coverUrl == null || coverUrl.isEmpty) return;
    _source = quad == null
        ? null
        : BravaisCoverSource(
            cardKey: cardKey,
            slotKey: slotKey,
            coverUrl: coverUrl,
            quad: quad,
            at: nowMs(),
          );
  }

  BravaisCoverSource? take(String? coverUrl, {required bool reducedMotion}) {
    final taken = _source;
    _source = null;
    if (taken == null ||
        coverUrl == null ||
        coverUrl.isEmpty ||
        reducedMotion) {
      return null;
    }
    if (nowMs() - taken.at > 1500) return null;
    return urls.identity(taken.coverUrl) == urls.identity(coverUrl)
        ? taken
        : null;
  }

  void park(String layerKey, BravaisCoverBackOrigin origin) =>
      _parked = (layerKey: layerKey, origin: origin);
  BravaisCoverBackOrigin? takeParked(String layerKey) {
    final parked = _parked;
    _parked = null;
    return parked?.layerKey == layerKey ? parked?.origin : null;
  }
}

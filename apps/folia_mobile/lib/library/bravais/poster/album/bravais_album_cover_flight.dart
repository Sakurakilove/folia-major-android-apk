import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../cover/bravais_cover_flight.dart';
import '../../cover/bravais_cover_flights.dart';
import '../../cover/bravais_cover_memory.dart';
import '../../cover/bravais_cover_quad.dart';
import '../../cover/bravais_cover_tiles.dart';
import 'bravais_album_cover.dart';
import 'bravais_album_entrance.dart';
import 'bravais_album_motion.dart';

// Create from the stage's discrete layer change before building its children: the overlay and hidden destination then share the first frame. Native layout activates the prepared flight; no widget update or channel is needed at landing.
typedef BravaisAlbumSettleTimer = VoidCallback Function(
  Duration delay,
  VoidCallback run,
);

class BravaisAlbumCoverFlight with WidgetsBindingObserver {
  BravaisAlbumCoverFlight({
    required this.layerKey,
    required this.coverUrl,
    required this.entrance,
    required this.memory,
    required this.flights,
    required this.tiles,
    required this.currentLayerKey,
    required this.reducedMotion,
    BravaisAlbumSettleTimer? schedule,
  }) : _schedule = schedule ?? _timer {
    WidgetsBinding.instance.addObserver(this);
    final source = memory.take(coverUrl, reducedMotion: reducedMotion());
    if (source == null) {
      _origin = memory.takeParked(layerKey);
    } else {
      _origin = (slotKey: source.slotKey, cardKey: source.cardKey);
      entrance.setCover(BravaisAlbumCoverState.pending);
      _flight = flights.toPoster(
        from: source,
        measure: () => measureBravaisCover(_box),
        shadow: _shadow,
        connected: () => !_closed && _box != null,
        imageReady: () => _box?.imageReady ?? false,
        onLand: () {
          if (!_closed) entrance.setCover(BravaisAlbumCoverState.landed);
        },
        deferred: true,
      );
    }
  }
  final String layerKey;
  final String? coverUrl;
  final BravaisAlbumEntrance entrance;
  final BravaisCoverMemory memory;
  final BravaisCoverFlights flights;
  final BravaisCoverTiles tiles;
  final String? Function() currentLayerKey;
  final bool Function() reducedMotion;
  final BravaisAlbumSettleTimer _schedule;
  final anchor = GlobalKey();
  BravaisCoverBackOrigin? _origin;
  BravaisCoverFlight? _flight;
  BravaisCoverQuad? _settled;
  BravaisCoverShadow? _settledShadow;
  VoidCallback? _cancelSettle;
  bool _laidOut = false, _closed = false, _resizeQueued = false;

  static VoidCallback _timer(Duration delay, VoidCallback run) {
    final timer = Timer(delay, run);
    return timer.cancel;
  }

  RenderBravaisAlbumCoverBox? get _box {
    final render = anchor.currentContext?.findRenderObject();
    return render is RenderBravaisAlbumCoverBox &&
            render.attached &&
            render.hasSize
        ? render
        : null;
  }

  BravaisCoverShadow _shadow(BravaisCoverQuad quad) {
    final box = _box;
    return box == null
        ? BravaisCoverShadow.none
        : BravaisCoverShadow(12, box.ink).atScale(quad.width, box.size.width);
  }

  // Connect to BravaisAlbumCover.onLayout. Do not measure here: ancestor safe-area layout has not necessarily completed yet.
  void didLayout() {
    if (_closed || _laidOut) return;
    _laidOut = true;
    if (_flight case final flight?) flights.begin(flight);
    _cancelSettle = _schedule(
      const Duration(milliseconds: 1300),
      captureGeometry,
    );
  }

  void captureGeometry() {
    if (_closed) return;
    final quad = measureBravaisCover(_box);
    if (quad != null) {
      _settled = quad;
      _settledShadow = _shadow(quad);
    }
  }

  @override
  void didChangeMetrics() {
    if (_closed || _resizeQueued) return;
    _resizeQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resizeQueued = false;
      captureGeometry();
    });
  }

  void dispose() {
    if (_closed) return;
    final box = _box,
        origin = _origin,
        from = _settled,
        shadow = _settledShadow,
        url = coverUrl;
    _closed = true;
    _cancelSettle?.call();
    WidgetsBinding.instance.removeObserver(this);
    if (!_laidOut && _flight != null) _flight!.finish(flights.nowMs(), -1);
    if (origin == null) return;
    if (currentLayerKey() == layerKey) {
      memory.park(layerKey, origin);
    } else if (from != null && shadow != null && url != null) {
      flights.back(
        reducedMotion: reducedMotion(),
        coverConnected: () => box?.attached ?? false,
        from: from,
        shadow: shadow,
        cardKey: origin.cardKey,
        coverUrl: url,
        findTile: () => tiles.find(origin.slotKey),
      );
    }
  }
}

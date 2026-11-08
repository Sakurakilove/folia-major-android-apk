import 'package:flutter/foundation.dart';

import 'bravais_cover_flight.dart';
import 'bravais_cover_memory.dart';
import 'bravais_cover_quad.dart';

part 'bravais_cover_return.dart';

// One bounded native overlay coordinator belongs to the original library host. Frames drive retained paint/layout only; no Platform Channel or image copy is involved.
class BravaisCoverFlights {
  BravaisCoverFlights({
    required this.frames,
    required this.nowMs,
    bool active = true,
  }) : _active = active,
       _visible = ValueNotifier(active);
  final Listenable frames;
  final double Function() nowMs;
  final entries = ValueNotifier<List<BravaisCoverFlight>>(const []);
  final ValueNotifier<bool> _visible;
  ValueListenable<bool> get visibility => _visible;
  final _flights = <BravaisCoverFlight>[], _returns = <_CoverReturn>[];
  BravaisCoverFlight? _current;
  int _tickNumber = 0;
  bool _attached = false, _active, _closed = false;
  BravaisCoverFlight fly({
    required String url,
    required BravaisCoverQuad from,
    required BravaisCoverQuad? Function() target,
    required double duration,
    required BravaisCoverShadow shadowFrom,
    required BravaisCoverShadow Function(BravaisCoverQuad) shadowTo,
    required BravaisCoverLanding landing,
    bool Function()? ready,
    bool Function()? lost,
    VoidCallback? onDone,
    bool deferred = false,
  }) {
    if (_closed) throw StateError('Cover flight coordinator is closed');
    stop();
    final flight = BravaisCoverFlight(
      url: url,
      from: from,
      target: target,
      startedAt: nowMs(),
      duration: duration,
      shadowFrom: shadowFrom,
      shadowTo: shadowTo,
      landing: landing,
      ready: ready,
      lost: lost,
      onDone: onDone,
      pending: deferred,
      onFinish: (_) => _sync(),
    );
    _current = flight;
    _flights.add(flight);
    _publish();
    _sync();
    return flight;
  }

  BravaisCoverFlight toPoster({
    required BravaisCoverSource from,
    required BravaisCoverQuad? Function() measure,
    required BravaisCoverShadow Function(BravaisCoverQuad) shadow,
    required bool Function() connected,
    required bool Function() imageReady,
    required VoidCallback onLand,
    bool deferred = false,
  }) => fly(
    url: from.coverUrl,
    from: from.quad,
    target: measure,
    duration: 640,
    shadowFrom: BravaisCoverShadow.none,
    shadowTo: shadow,
    landing: BravaisCoverLanding.swap,
    lost: () => !connected(),
    ready: imageReady,
    onDone: onLand,
    deferred: deferred,
  );

  void begin(BravaisCoverFlight flight) {
    if (_closed || !_flights.contains(flight)) return;
    flight.begin(nowMs());
    _sync();
  }

  void stop() => _current?.finish(nowMs(), _tickNumber);
  void setActive(bool value) {
    if (_closed || _active == value) return;
    _active = value;
    _visible.value = value;
    if (value) _tick();
    _sync();
  }

  void _publish() => entries.value = List.unmodifiable(_flights);
  void _tick() {
    if (_closed || !_active) return;
    _tickNumber++;
    final now = nowMs();
    final running = List<BravaisCoverFlight>.of(_flights);
    for (final waiting in List<_CoverReturn>.of(_returns)) {
      if (waiting.step(now)) _returns.remove(waiting);
      if (_closed) return;
    }
    var changed = false;
    for (final flight in running) {
      flight.step(now, _tickNumber);
      if (_closed) return;
      if (flight.removed) {
        _flights.remove(flight);
        if (identical(_current, flight)) _current = null;
        flight.dispose();
        changed = true;
      }
    }
    if (changed) _publish();
    _sync();
  }

  void _sync() {
    final wanted =
        !_closed &&
        _active &&
        (_flights.any((f) => !f.pending) || _returns.isNotEmpty);
    if (_attached == wanted) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_tick);
    } else {
      frames.removeListener(_tick);
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _sync();
    _returns.clear();
    for (final flight in _flights) {
      flight.dispose();
    }
    _flights.clear();
    _current = null;
    entries.dispose();
    _visible.dispose();
  }
}

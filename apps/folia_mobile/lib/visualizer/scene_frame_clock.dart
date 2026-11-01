import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../app/frame_signal.dart';

// Every style/background shares one full-rate display clock; a static scene with no live consumers schedules no frames.
class SceneFrameClock extends FrameSignal {
  SceneFrameClock(TickerProvider vsync) {
    _ticker = vsync.createTicker((_) => tick());
  }
  late final Ticker _ticker;
  bool _foreground = true, _closed = false;
  bool get isRunning => _ticker.isActive;
  void setForeground(bool value) {
    if (_closed || _foreground == value) return;
    _foreground = value;
    _sync();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  void _sync() {
    if (_closed) return;
    final wanted = _foreground && hasListeners;
    if (wanted && !_ticker.isActive) _ticker.start();
    if (!wanted && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _closed = true;
    _ticker.dispose();
    super.dispose();
  }
}

// Offscreen retained scenes release their parent clock subscription without resetting their absolute animation time.
class SceneFrameDomain extends ChangeNotifier {
  SceneFrameDomain(this.clock, [this._active = true]);
  final Listenable clock;
  bool _active, _attached = false, _closed = false;
  void setActive(bool value) {
    if (_closed || _active == value) return;
    _active = value;
    _sync();
    if (value) notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  void _frame() {
    if (!_closed && _active) notifyListeners();
  }

  void _sync() {
    if (_closed) return;
    final wanted = _active && hasListeners;
    if (_attached == wanted) return;
    _attached = wanted;
    if (wanted) {
      clock.addListener(_frame);
    } else {
      clock.removeListener(_frame);
    }
  }

  @override
  void dispose() {
    _closed = true;
    if (_attached) clock.removeListener(_frame);
    super.dispose();
  }
}

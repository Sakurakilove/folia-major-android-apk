import 'package:flutter/foundation.dart';

import '../visualizer/motion/follow_spring.dart';
import 'player_bottom_geometry.dart';

// Source subtitle bottom: direct drag/Android rectangle updates, independently sprung bar presence, and no platform messages per frame.
class PlayerSubtitleBottomSignal extends ChangeNotifier
    implements ValueListenable<double> {
  PlayerSubtitleBottomSignal({
    required this.offset,
    required this.androidClearance,
    required this.chromeHidden,
    required this.progressBarHidden,
    required this.isPlayerHost,
    required this.isAndroid,
    required this.frames,
    required this.milliseconds,
  }) {
    _absent = _isAbsent;
    _presence = MotionFollowSpring(
      _absent ? 0 : 1,
      stiffness: 280,
      damping: 28,
    );
    _value = _resolve();
    offset.addListener(_geometryChanged);
    androidClearance.addListener(_geometryChanged);
    chromeHidden.addListener(_presenceChanged);
    progressBarHidden.addListener(_presenceChanged);
  }
  final ValueListenable<double> offset, androidClearance;
  final ValueListenable<bool> chromeHidden, progressBarHidden;
  final bool isPlayerHost, isAndroid;
  final Listenable frames;
  final double Function() milliseconds;
  late final MotionFollowSpring _presence;
  late double _value;
  late bool _absent;
  bool _attached = false, _closed = false;
  bool get _isAbsent =>
      chromeHidden.value || (isPlayerHost && progressBarHidden.value);
  @override
  double get value {
    if (!_closed && !hasListeners) {
      _presence.advance(milliseconds());
      _value = _resolve();
    }
    return _value;
  }

  double _resolve() => resolveSubtitleBottom(
    isPlayerHost: isPlayerHost,
    offset: offset.value,
    presence: _presence.value,
    isAndroid: isAndroid,
    androidClearance: androidClearance.value,
  );
  void _publish() {
    final next = _resolve();
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  void _geometryChanged() => _publish();
  void _presenceChanged() {
    final absent = _isAbsent;
    if (absent == _absent) return;
    _absent = absent;
    _presence.setTarget(absent ? 0 : 1, milliseconds());
    _sync();
  }

  void _frame() {
    _presence.advance(milliseconds());
    _publish();
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
    final wanted = !_closed && hasListeners && _presence.isAnimating;
    if (wanted == _attached) return;
    _attached = wanted;
    if (wanted) {
      frames.addListener(_frame);
    } else {
      frames.removeListener(_frame);
    }
  }

  @override
  void dispose() {
    _closed = true;
    if (_attached) frames.removeListener(_frame);
    offset.removeListener(_geometryChanged);
    androidClearance.removeListener(_geometryChanged);
    chromeHidden.removeListener(_presenceChanged);
    progressBarHidden.removeListener(_presenceChanged);
    super.dispose();
  }
}

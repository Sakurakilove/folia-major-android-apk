part of 'bravais_card_motion.dart';

// Only a visible loading frame owns this repeating CSS animation. Hiding detaches its frame source while retaining absolute phase for resume.
extension _BravaisCardBreathe on BravaisCardMotion {
  void _syncBreathe() {
    final wanted =
        loading && !reducedMotion && _look.face.kind == BravaisTileKind.wall;
    if (wanted) {
      _breatheStarted ??= nowMs();
    } else {
      _breatheStarted = null;
    }
    _advanceBreathe(nowMs());
  }

  void _advanceBreathe(double now) {
    final started = _breatheStarted;
    if (started == null) {
      _breatheOpacity = 1;
      return;
    }
    final phase = ((now - started) / 2400) % 1;
    final first = phase < .5, p = first ? phase * 2 : (phase - .5) * 2;
    final progress = cssBezier(.42, 0, .58, 1, p);
    _breatheOpacity = first ? .55 + .45 * progress : 1 - .45 * progress;
  }
}

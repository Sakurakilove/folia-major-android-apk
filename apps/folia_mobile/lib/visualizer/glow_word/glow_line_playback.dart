import 'package:flutter/foundation.dart';

import 'glow_line_motion.dart';
import 'glow_word_motion.dart';

// One visible-line subscription samples local anchors and all word tracks before painting; no per-frame platform calls or per-word tickers.
class GlowLinePlayback extends ChangeNotifier {
  GlowLinePlayback({
    required this.words,
    required this.line,
    required this.frames,
    required this.audioChanges,
    required this.audioTime,
    required this.milliseconds,
    required this.isPlaying,
    required this.isGlowBlurQuantized,
    this.onRetired,
  }) {
    _previousAudio = audioTime();
    audioChanges.addListener(_audioChanged);
    _sync();
  }
  final List<GlowWordMotion> words;
  final GlowLineMotion line;
  final Listenable frames, audioChanges;
  final double Function() audioTime, milliseconds;
  final bool Function() isPlaying, isGlowBlurQuantized;
  final VoidCallback? onRetired;
  late double _previousAudio;
  bool _active = true, _attached = false, _closed = false, _reported = false;
  bool get wantsFrames =>
      isPlaying() || line.isAnimating || words.any((w) => w.isAnimating);
  void setActive(bool value) {
    if (_closed || _active == value) return;
    _active = value;
    if (value) _sample();
    _sync();
  }

  void leave({required bool textHidden}) {
    if (_closed) return;
    line.leave(milliseconds(), textHidden: textHidden);
    _sample();
    _sync();
  }

  void _audioChanged() {
    if (_closed || !_active) return;
    _sample();
    _sync();
  }

  void _frame() {
    _sample();
    _sync();
  }

  void _sample() {
    final time = audioTime(),
        now = milliseconds(),
        changed = time != _previousAudio;
    _previousAudio = time;
    for (final word in words) {
      if (changed) {
        word.acceptTime(time, now, glowBlurQuantized: isGlowBlurQuantized());
      }
      word.advance(now);
    }
    line.advance(now);
    notifyListeners();
    if (line.retired && !_reported) {
      _reported = true;
      onRetired?.call();
    }
  }

  void _sync() {
    final wanted = !_closed && _active && !line.retired && wantsFrames;
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
    audioChanges.removeListener(_audioChanged);
    if (_attached) frames.removeListener(_frame);
    super.dispose();
  }
}

import '../visualizer/glow_word/glow_word_timing.dart';
import '../visualizer/motion/scalar_value.dart';
import '../visualizer/motion/time_driven_motion.dart';
import 'partita_layout_models.dart';

// Original chunk and guide state changes run beside the shared word tracks; no per-frame channels and no independent ticker.
class PartitaChunkMotion implements TimeDrivenMotion {
  PartitaChunkMotion(
    this.chunk,
    this.profile,
    double now, {
    required bool showGuides,
  }) : _showGuides = showGuides {
    _animate(now);
    if (showGuides) _animateGuides(now);
  }
  final PartitaChunkLayout chunk;
  final GlowWordRenderProfile profile;
  final opacity = MotionScalarValue(1),
      scale = MotionScalarValue(1),
      x = MotionScalarValue(0),
      y = MotionScalarValue(0),
      rotate = MotionScalarValue(0);
  final guideScale = MotionScalarValue(1), guideOpacity = MotionScalarValue(1);
  bool _showGuides;
  String status = 'waiting';
  double? _lastTime;
  bool get showGuides => _showGuides;
  bool get left => chunk.rowIndex.isEven;
  @override
  bool get isAnimating =>
      opacity.isAnimating ||
      scale.isAnimating ||
      x.isAnimating ||
      y.isAnimating ||
      rotate.isAnimating ||
      (_showGuides && (guideScale.isAnimating || guideOpacity.isAnimating));
  void _animate(double now) {
    final waiting = status == 'waiting',
        transition = status == 'active'
            ? <String, dynamic>{
                'type': 'spring',
                'stiffness': 200,
                'damping': 20,
                'opacity': {'duration': .1},
              }
            : <String, dynamic>{'duration': .4, 'ease': 'easeOut'};
    opacity.animateVariant(
      'opacity',
      waiting ? 0 : 1,
      transition,
      now,
      css: true,
    );
    scale.animateVariant('scale', waiting ? .85 : 1, transition, now);
    x.animateVariant(
      'x',
      waiting ? chunk.config.x + (left ? -40 : 40) : chunk.config.x,
      transition,
      now,
    );
    y.animateVariant('y', chunk.config.y, transition, now);
    rotate.animateVariant('rotate', chunk.config.rotate, transition, now);
  }

  void _animateGuides(double now) {
    final target = status == 'waiting' ? 0 : 1;
    const transition = {'duration': .4, 'ease': 'easeOut'};
    guideScale.animateVariant('scaleX', target, transition, now);
    guideOpacity.animateVariant('opacity', target, transition, now, css: true);
  }

  void setShowGuides(bool value, double now) {
    if (value == _showGuides) return;
    _showGuides = value;
    guideScale.jump(1, now);
    guideScale.seedVariant(1);
    guideOpacity.jump(1, now);
    guideOpacity.seedVariant(1);
    if (value) _animateGuides(now);
  }

  @override
  void acceptTime(double time, double now) {
    if (_lastTime == time || chunk.words.isEmpty) return;
    _lastTime = time;
    final end = profile.activeEnd(chunk.words.last),
        start = chunk.words.first.start - profile.wordLookahead;
    final next = time >= start && time <= end
        ? 'active'
        : time > end
        ? 'passed'
        : 'waiting';
    if (next == status) return;
    advance(now);
    status = next;
    _animate(now);
    if (_showGuides) _animateGuides(now);
  }

  @override
  void advance(double now) {
    opacity.advance(now);
    scale.advance(now);
    x.advance(now);
    y.advance(now);
    rotate.advance(now);
    if (_showGuides) {
      guideScale.advance(now);
      guideOpacity.advance(now);
    }
  }
}

import '../motion/scalar_value.dart';
import 'glow_word_timing.dart';

// Classic/Partita's three line-transition profiles and the separate text-hidden fade; omitted fields keep the original Motion defaults.
class GlowLineMotion {
  GlowLineMotion(GlowWordRenderProfile? profile, double now) {
    final source = glowWordLineContainerMotion(profile);
    final initial = source['initial'] as Map;
    opacity.jump((initial['opacity'] as num).toDouble(), now);
    scale.jump((initial['scale'] as num).toDouble(), now);
    blur.jump(_blur(initial['filter'] as String), now);
    opacity.seedVariant(initial['opacity']);
    scale.seedVariant(initial['scale']);
    blur.seedVariant(initial['filter']);
    _exit = Map<String, dynamic>.from(source['exit'] as Map);
    _animate(Map<String, dynamic>.from(source['animate'] as Map), now);
  }
  final opacity = MotionScalarValue(1),
      scale = MotionScalarValue(1),
      blur = MotionScalarValue(0);
  late final Map<String, dynamic> _exit;
  bool leaving = false, _hiddenExit = false;
  bool get isAnimating =>
      opacity.isAnimating || scale.isAnimating || blur.isAnimating;
  bool get retired =>
      leaving &&
      !opacity.isAnimating &&
      (_hiddenExit || !scale.isAnimating && !blur.isAnimating);
  static double _blur(String value) => value == 'none'
      ? 0
      : double.parse(RegExp(r'[\d.]+').firstMatch(value)![0]!);
  void _animate(Map<String, dynamic> target, double now) {
    final transition = Map<String, dynamic>.from(
      target['transition'] as Map? ?? const {},
    );
    if (target.containsKey('opacity')) {
      opacity.animateVariant(
        'opacity',
        target['opacity'],
        transition,
        now,
        css: true,
      );
    }
    if (target.containsKey('scale')) {
      scale.animateVariant('scale', target['scale'], transition, now);
    }
    if (target.containsKey('filter')) {
      blur.animateVariant(
        'filter',
        _blur(target['filter'] as String),
        transition,
        now,
        css: true,
        identity: target['filter'],
      );
    }
  }

  void leave(double now, {required bool textHidden}) {
    if (leaving) return;
    leaving = true;
    _hiddenExit = textHidden;
    _animate(
      textHidden
          ? {
              'opacity': 0,
              'transition': {'duration': .2, 'ease': 'easeOut'},
            }
          : _exit,
      now,
    );
  }

  void advance(double now) {
    opacity.advance(now);
    scale.advance(now);
    blur.advance(now);
  }
}

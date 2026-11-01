import '../../lyrics/grapheme_timing.dart';
import '../../lyrics/lyric_types.dart';
import '../motion/color_value.dart';
import '../motion/color_value_animation.dart';
import '../motion/scalar_value.dart';
import 'glow_glyph_motion.dart';
import 'glow_ramp_spec.dart';
import 'glow_word_ripple.dart';
import 'glow_word_timing.dart';
import 'glow_word_variants.dart';

// Source GlowWord's waiting/active/passed machine; audio time selects states, local animation time drives the full original effects.
class GlowWordMotion {
  GlowWordMotion({
    required this.word,
    required this.profile,
    required this.config,
    required this.intensity,
    required this.baseColor,
    required this.activeColor,
    required this.rippleScale,
    this.chorus = false,
    this.enableWordRotation = true,
    this.baseColorAnimatable = true,
    this.activeColorAnimatable = true,
    this.baseColorKey,
    this.activeColorKey,
  }) : bodyColor = MotionColorValue(
         baseColor,
         animatable: baseColorAnimatable,
         variantKey: baseColorKey,
       ) {
    final waiting = glowWordLayoutVariant(
      'waiting',
      config,
      intensity: intensity,
      enableWordRotation: enableWordRotation,
    );
    layout = {
      for (final key in ['x', 'y', 'rotate', 'scale', 'opacity'])
        key: MotionScalarValue((waiting[key] as num).toDouble()),
    };
    graphemes = buildWordGraphemeTimings(word);
    final count = graphemes.length > 1 ? graphemes.length : 1;
    glyphs = [
      for (var i = 0; i < count; i++)
        GlowGlyphMotion(
          resolveGlowRamp(
            duration: profile.displayDuration(word),
            revealMode: profile.wordRevealMode,
            index: graphemes.length > 1 ? i : null,
            total: graphemes.length > 1 ? count : null,
            charStartTime: graphemes.length > 1 ? graphemes[i].start : null,
            charEndTime: graphemes.length > 1 ? graphemes[i].end : null,
            wordStartTime: word.start,
          ),
          activeColor,
        ),
    ];
  }
  final LyricWord word;
  final GlowWordRenderProfile profile;
  final GlowWordGeometry config;
  final String intensity;
  final MotionRgba baseColor, activeColor;
  final double rippleScale;
  final bool chorus, enableWordRotation;
  final bool baseColorAnimatable, activeColorAnimatable;
  final String? baseColorKey, activeColorKey;
  late final Map<String, MotionScalarValue> layout;
  late final List<GraphemeTiming> graphemes;
  late final List<GlowGlyphMotion> glyphs;
  final MotionColorValue bodyColor;
  final bodyBlur = MotionScalarValue(10, variantTarget: 'blur(10px)');
  final ripples = <GlowWordRipple>[];
  String status = 'waiting';
  double? _lastAudioTime;
  bool quantized = false;
  bool get isAnimating =>
      bodyColor.isAnimating ||
      bodyBlur.isAnimating ||
      layout.values.any((v) => v.isAnimating) ||
      glyphs.any((g) => g.isAnimating) ||
      ripples.any((r) => r.isAnimating);

  // Call only for an actual MotionValue time change; mounting alone must not skip the original waiting pose.
  void acceptTime(
    double audioTime,
    double now, {
    bool glowBlurQuantized = false,
  }) {
    if (_lastAudioTime == audioTime) return;
    _lastAudioTime = audioTime;
    final next = profile.status(word, audioTime);
    if (next == status) return;
    advance(now);
    if (status == 'active') {
      for (final ripple in ripples) {
        if (!ripple.exiting) ripple.leave(now);
      }
    }
    status = next;
    quantized = glowBlurQuantized;
    final pose = glowWordLayoutVariant(
      status,
      config,
      intensity: intensity,
      enableWordRotation: enableWordRotation,
    );
    final transition = Map<String, dynamic>.from(pose['transition'] as Map);
    for (final entry in layout.entries) {
      entry.value.animateVariant(
        entry.key,
        pose[entry.key],
        transition,
        now,
        css: entry.key == 'opacity',
      );
    }
    final body = glowWordBodyVariant(
      status,
      baseColor: '',
      activeColor: '',
      duration: profile.displayDuration(word),
      wordRevealMode: profile.wordRevealMode,
    );
    final bodyTransition = Map<String, dynamic>.from(body['transition'] as Map);
    bodyColor.animate(
      'color',
      status == 'active' ? activeColor : baseColor,
      bodyTransition,
      now,
      animatable: status == 'active'
          ? activeColorAnimatable
          : baseColorAnimatable,
      variantKey: status == 'active' ? activeColorKey : baseColorKey,
    );
    bodyBlur.animateVariant(
      'filter',
      status == 'waiting' ? 10 : 0,
      bodyTransition,
      now,
      css: true,
      identity: body['filter'],
    );
    for (final glyph in glyphs) {
      glyph.transition(
        status,
        now,
        quantized: quantized,
        revealMode: profile.wordRevealMode,
      );
    }
    if (chorus && status == 'active') {
      ripples.add(GlowWordRipple(rippleScale, now));
    }
  }

  void advance(double now) {
    for (final value in layout.values) {
      value.advance(now);
    }
    bodyColor.advance(now);
    bodyBlur.advance(now);
    for (final glyph in glyphs) {
      glyph.advance(now);
    }
    for (final ripple in ripples) {
      ripple.advance(now);
    }
    ripples.removeWhere((r) => r.retired);
  }
}

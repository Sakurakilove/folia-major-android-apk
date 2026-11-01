import '../../../visualizer/motion/bezier.dart';

// Original WAAPI face transforms, including no backwards fill on delayed exits and complete backwards fill on incoming waves.
enum BravaisTileFlightKind {
  flipOut,
  flipIn,
  waveOut,
  waveIn,
  fadeOut,
  fadeIn,
  entranceFade,
}

class BravaisTileSample {
  const BravaisTileSample({
    this.y = 0,
    this.scale = 1,
    this.rotateY = 0,
    this.opacity = 1,
    this.effect = false,
    this.transformEffect = false,
    this.opacityEffect = false,
  });
  final double y, scale, rotateY, opacity;
  final bool effect, transformEffect, opacityEffect;
}

class BravaisTileFlight {
  const BravaisTileFlight(
    this.kind,
    this.start,
    this.duration, {
    this.direction = 1,
  });
  final BravaisTileFlightKind kind;
  final double start, duration;
  final int direction;
  bool get outgoing =>
      kind == BravaisTileFlightKind.flipOut ||
      kind == BravaisTileFlightKind.waveOut ||
      kind == BravaisTileFlightKind.fadeOut;
  bool done(double now) => now >= start + duration;
  BravaisTileSample sample(double now) {
    if (now < start && outgoing) return const BravaisTileSample();
    final p = ((now - start) / duration).clamp(0.0, 1.0);
    final value = switch (kind) {
      BravaisTileFlightKind.flipOut => cssBezier(.55, 0, .9, .45, p),
      BravaisTileFlightKind.flipIn => cssBezier(.2, .7, .25, 1, p),
      BravaisTileFlightKind.waveOut => cssBezier(.4, 0, 1, 1, p),
      BravaisTileFlightKind.waveIn => cssBezier(.2, .9, .3, 1.04, p),
      BravaisTileFlightKind.fadeOut => cssBezier(.42, 0, 1, 1, p),
      BravaisTileFlightKind.fadeIn ||
      BravaisTileFlightKind.entranceFade => cssBezier(0, 0, .58, 1, p),
    };
    return switch (kind) {
      BravaisTileFlightKind.flipOut => BravaisTileSample(
        rotateY: 90 * direction * value,
        effect: true,
        transformEffect: true,
      ),
      BravaisTileFlightKind.flipIn => BravaisTileSample(
        rotateY: -90 * direction * (1 - value),
        effect: true,
        transformEffect: true,
      ),
      BravaisTileFlightKind.waveOut => BravaisTileSample(
        y: -90 * value,
        scale: 1 - .12 * value,
        opacity: (1 - value).clamp(0, 1),
        effect: true,
        transformEffect: true,
        opacityEffect: true,
      ),
      BravaisTileFlightKind.waveIn => BravaisTileSample(
        y: -90 * (1 - value),
        scale: .88 + .12 * value,
        opacity: value.clamp(0, 1),
        effect: true,
        transformEffect: true,
        opacityEffect: true,
      ),
      BravaisTileFlightKind.fadeOut => BravaisTileSample(
        opacity: 1 - value,
        effect: true,
        opacityEffect: true,
      ),
      BravaisTileFlightKind.fadeIn || BravaisTileFlightKind.entranceFade =>
        BravaisTileSample(opacity: value, effect: true, opacityEffect: true),
    };
  }
}

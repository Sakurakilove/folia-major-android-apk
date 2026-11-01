import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/visualizer/glow_word/glow_ramp_spec.dart';
import 'package:folia_mobile/visualizer/motion/color_value.dart';
import 'package:folia_mobile/visualizer/motion/scalar_value.dart';
import 'package:folia_mobile/visualizer/motion/follow_spring.dart';

// This validates source parameters and color values; final full-scene/font/backend fidelity remains a separate required gate.
void main() {
  final data = jsonDecode(
    File('test/fixtures/glow_ramp_reference.json').readAsStringSync(),
  ) as Map;
  void equal(dynamic a, dynamic b) {
    if (a is num && b is num && (a - b).abs() < 1e-8) return;
    if (a is List && b is List && a.length == b.length) {
      for (var i = 0; i < a.length; i++) {
        equal(a[i], b[i]);
      }
      return;
    }
    if (a is Map && b is Map && a.length == b.length) {
      for (final key in a.keys) {
        equal(a[key], b[key]);
      }
      return;
    }
    if (a != b) throw StateError('$a != $b');
  }

  for (final row in data['ramps']) {
    final c = row['custom'] as Map;
    final ramp = resolveGlowRamp(
      duration: (c['duration'] as num).toDouble(),
      revealMode: c['wordRevealMode'],
      index: c['index'],
      total: c['total'],
      charStartTime: (c['charStartTime'] as num?)?.toDouble(),
      charEndTime: (c['charEndTime'] as num?)?.toDouble(),
      wordStartTime: (c['wordStartTime'] as num?)?.toDouble(),
    );
    final transition = Map.of(row['transition']);
    transition.putIfAbsent('delay', () => 0);
    equal(ramp.transition, transition);
    equal(ramp.peaks, row['peaks']);
    equal([
      ramp.inner * (row['quantized'] ? .4 : 1),
      ramp.outer * (row['quantized'] ? .4 : 1),
    ], row['radii']);
  }
  for (final row in data['colors']) {
    final from = MotionRgba.parse(row['from'])!,
        to = MotionRgba.parse(row['to'])!;
    for (final sample in row['samples']) {
      equal(
        from.mixed(to, (sample['progress'] as num).toDouble()).toJson(),
        sample['value'],
      );
    }
  }
  final continuity = MotionScalarValue(0);
  continuity.animateVariant('x', 100, {'duration': 1, 'ease': 'linear'}, 0);
  continuity.advance(250);
  continuity.animateVariant('x', 100, {'duration': .1}, 250);
  continuity.advance(500);
  equal(continuity.value, 50);
  equal(continuity.velocity(500), 25 * 1000 / 30);
  equal(continuity.velocity(531), 0);
  for (final row in data['followers']) {
    final o = row['options'] as Map;
    final spring = MotionFollowSpring(
      1,
      stiffness: (o['stiffness'] as num).toDouble(),
      damping: (o['damping'] as num).toDouble(),
      mass: (o['mass'] as num?)?.toDouble() ?? 1,
    );
    for (final step in row['steps']) {
      final now = (step['ms'] as num).toDouble();
      if (step.containsKey('set')) {
        spring.setTarget((step['set'] as num).toDouble(), now);
      }
      if (step['tick'] == true) spring.advance(now);
      equal(spring.value, step['value']);
      equal(spring.isAnimating, step['running']);
    }
  }
  stdout.writeln(
    '${data['ramps'].length} original glyph ramps and 30 Motion color samples passed.',
  );
}

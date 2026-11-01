import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/classic/classic_layout.dart';
import 'package:folia_mobile/visualizer/motion/physical_spring.dart';
import 'package:folia_mobile/classic/classic_tuning.dart';
import 'package:folia_mobile/lyrics/lyric_types.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_word_timing.dart';
import 'package:folia_mobile/visualizer/glow_word/glow_word_variants.dart';

// Numeric plans only: the source width stub does not certify either rendering engine's font/raster output.
void main() {
  final data = jsonDecode(
    File('test/fixtures/glow_word_reference.json').readAsStringSync(),
  ) as Map;
  void equal(dynamic actual, dynamic expected, String path) {
    if (actual is num && expected is num && (actual - expected).abs() <= 1e-8) {
      return;
    }
    if (actual is Map && expected is Map && actual.length == expected.length) {
      for (final key in expected.keys) {
        equal(actual[key], expected[key], '$path.$key');
      }
      return;
    }
    if (actual is List &&
        expected is List &&
        actual.length == expected.length) {
      for (var i = 0; i < actual.length; i++) {
        equal(actual[i], expected[i], '$path[$i]');
      }
      return;
    }
    // JS/V8 and native libm may spell the last insignificant digit of a CSS rem number differently.
    if (actual is String &&
        expected is String &&
        actual.endsWith('rem') &&
        expected.endsWith('rem')) {
      equal(
        double.parse(actual.replaceAll('rem', '')),
        double.parse(expected.replaceAll('rem', '')),
        path,
      );
      return;
    }
    if (actual != expected) throw StateError('$path: $actual != $expected');
  }

  for (final row in data['physics']) {
    final config = row['config'];
    final spring = MotionPhysicalSpring(
      (config['stiffness'] as num).toDouble(),
      (config['damping'] as num).toDouble(),
      (config['mass'] as num).toDouble(),
      (row['from'] as num).toDouble(),
      (row['to'] as num).toDouble(),
      (row['velocity'] as num).toDouble(),
    );
    for (final sample in row['samples']) {
      final seconds = (sample['ms'] as num).toDouble() / 1000;
      equal(spring.x(seconds), sample['value'], 'spring.position');
      equal(spring.dx(seconds), sample['velocity'], 'spring.velocity');
      equal(spring.isDone(seconds), sample['done'], 'spring.done');
    }
  }
  for (final row in data['layouts']) {
    final line = LyricLine.fromJson(Map<String, dynamic>.from(row['line']));
    final tuning = ClassicTuning.resolve(
      Map<String, dynamic>.from(row['tuning']),
      Map<String, dynamic>.from(row['tuning']),
    );
    final layout = buildClassicLineLayout(
      line: line,
      displayWords: line.words,
      intensity: row['intensity'],
      tuning: tuning,
      lyricsFontScale: row['lyricsFontScale'],
      viewportWidth: (row['viewportWidth'] as num).toDouble(),
      measureWord: (text, font) => text.length * font * .57,
    );
    equal(layout.toJson(), row['expected'], 'layout');
  }
  for (final row in data['variantCases']) {
    final c = row['config'], custom = row['custom'];
    final config = ClassicWordConfig(
      id: '',
      x: c['x'],
      y: c['y'],
      rotate: (c['rotate'] as num).toDouble(),
      scale: c['scale'],
      marginRight: '',
      alignSelf: '',
      passedRotate: (c['passedRotate'] as num).toDouble(),
    );
    for (final state in ['waiting', 'active', 'passed']) {
      equal(
        glowWordLayoutVariant(
          state,
          config,
          intensity: row['intensity'],
          enableWordRotation: row['rotation'],
        ),
        row['states'][state]['layout'],
        'word.layout.$state',
      );
      equal(
        glowWordBodyVariant(
          state,
          baseColor: custom['baseColor'],
          activeColor: custom['activeColor'],
          duration: custom['duration'],
          wordRevealMode: row['reveal'],
        ),
        row['states'][state]['body'],
        'word.body.$state',
      );
    }
  }
  for (final row in data['profiles']) {
    final profile = GlowWordRenderProfile(
      LyricLine.fromJson(Map<String, dynamic>.from(row['line'])),
    );
    equal(profile.toJson(), row['expected'], 'profile');
    equal(glowWordLineContainerMotion(profile), row['motion'], 'motion');
    for (final item in row['words']) {
      final word = LyricWord.fromJson(Map<String, dynamic>.from(item['word']));
      equal(profile.activeEnd(word), item['end'], 'activeEnd');
      equal(profile.displayDuration(word), item['duration'], 'displayDuration');
    }
  }
  equal(glowWordLineContainerMotion(null), data['nullMotion'], 'nullMotion');
  stdout.writeln(
    '${data['layouts'].length} original Classic layouts, word states, timing and 150 spring position/velocity/rest samples matched; frontend parity remains unverified.',
  );
}

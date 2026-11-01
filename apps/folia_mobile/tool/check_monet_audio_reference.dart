import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/audio/analysis/spectrum_snapshot.dart';
import 'package:folia_mobile/monet/audio/monet_audio_geometry.dart';

// Original draw coordinates are checked without a browser, screenshots, emulator or real-time benchmark.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/monet_audio_reference.json').readAsStringSync(),
  ) as Map;
  final geometry = MonetAudioGeometry(), frame = SpectrumSnapshot();
  void close(double actual, num expected) {
    if ((actual - expected).abs() > 1e-9) {
      throw StateError('$actual != $expected');
    }
  }

  for (final data in fixture['cases'] as List) {
    frame.binCount = data['length'] as int;
    frame.power = (data['power'] as num).toDouble();
    for (var i = 0; i < 5; i++) {
      frame.bands[i] = (data['bands'][i] as num).toDouble();
    }
    for (var i = 0; i < frame.binCount; i++) {
      frame.bins[i] = data['raw'][i] as int;
    }
    geometry.update(
      audio: frame,
      width: (data['width'] as num).toDouble(),
      height: (data['height'] as num).toDouble(),
      nowMs: (data['nowMs'] as num).toDouble(),
      line: data['mode'] == 'line',
      staticMode: data['staticMode'] as bool,
    );
    for (var i = 0; i < geometry.x.length; i++) {
      if (data['mode'] == 'line') {
        close(geometry.x[i], data['points'][i][0] as num);
        close(geometry.y[i], data['points'][i][1] as num);
      } else {
        close(geometry.x[i], data['bars'][i][0] as num);
        close(geometry.y[i], data['bars'][i][1] as num);
        close(geometry.barWidth, data['bars'][i][2] as num);
        close(
          (data['height'] as num) - geometry.y[i],
          data['bars'][i][3] as num,
        );
      }
    }
  }
  stdout.writeln(
    'Original 72-bar/curve geometry, spectrum windows, fallback bands and static-preview checks passed.',
  );
}

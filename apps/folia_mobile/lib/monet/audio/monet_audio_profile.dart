import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio/analysis/spectrum_snapshot.dart';

// AudioOverlay.tsx frequency windows and fallback profile; windows depend only on FFT length.
const monetAudioBarCount = 72;

class _Window {
  _Window(int index, int length) {
    final normalized = index / (monetAudioBarCount - 1),
        usable = math.max(1, length - 6);
    final center = 6 + math.exp(normalized * math.log(usable + 1)) - 1;
    final softness = 1 - (normalized - .5).abs() * 2,
        radius = math.max(1, (5 - softness * 3).round());
    start = math.max(6, (center - radius).floor());
    end = math.min(length - 1, (center + radius).ceil());
    weights = Float64List(math.max(0, end - start + 1));
    for (var i = start; i <= end; i++) {
      final weight = math.max(.1, 1 - (i - center).abs() / (radius + 1));
      weights[i - start] = weight;
      total += weight;
    }
    noise = 16 + (1 - normalized) * 12;
    power = 1.8 + (1 - normalized) * .4;
    compensation = .52 + normalized * .62;
    lift = .92 + math.sqrt(normalized) * .14;
  }
  late final int start, end;
  late final Float64List weights;
  double total = 0;
  late final double noise, power, compensation, lift;
  double sample(Uint8List bytes) {
    var sum = 0.0;
    for (var i = start; i <= end; i++) {
      sum += bytes[i] * weights[i - start];
    }
    final average = total > 0 ? sum / total : 0.0;
    final normalized = ((average - noise) / (255 - noise)).clamp(0.0, 1.0);
    return (math.pow(normalized, power) * compensation * lift).clamp(0.0, 1.0);
  }
}

class MonetAudioProfile {
  final values = Float64List(monetAudioBarCount), anchors = Float64List(11);
  List<_Window> _windows = const [];
  int _length = -1;
  Float64List update(SpectrumSnapshot frame) {
    if (frame.binCount > 6) {
      if (frame.binCount != _length) {
        _length = frame.binCount;
        _windows = List.generate(
          monetAudioBarCount,
          (i) => _Window(i, _length),
          growable: false,
        );
      }
      for (var i = 0; i < values.length; i++) {
        values[i] = _windows[i].sample(frame.bins);
      }
    } else {
      final bass = frame.bass / 255,
          low = frame.lowMid / 255,
          mid = frame.mid / 255,
          vocal = frame.vocal / 255,
          treble = frame.treble / 255;
      anchors[0] = bass * 1.08;
      anchors[1] = bass * .96;
      anchors[2] = bass * .74 + low * .26;
      anchors[3] = low;
      anchors[4] = low * .58 + mid * .42;
      anchors[5] = mid;
      anchors[6] = mid * .42 + vocal * .58;
      anchors[7] = vocal;
      anchors[8] = vocal * .48 + treble * .52;
      anchors[9] = treble;
      anchors[10] = treble * .82;
      for (var i = 0; i < anchors.length; i++) {
        anchors[i] = anchors[i].clamp(0.0, 1.0);
      }
      for (var i = 0; i < values.length; i++) {
        final normalized = i / (monetAudioBarCount - 1),
            logIndex = math.log(1 + normalized * 9) / math.ln10;
        final scaled = logIndex * (anchors.length - 1),
            lower = scaled.floor(),
            upper = math.min(lower + 1, anchors.length - 1);
        final value =
            anchors[lower] +
            (anchors[upper] - anchors[lower]) * (scaled - lower);
        final contour =
            .92 +
            math.sin(normalized * math.pi * 3.4 - math.pi * .3) * .08 +
            math.sin(normalized * math.pi * 9.2 + math.pi * .2) * .035;
        values[i] = (value * contour).clamp(0.0, 1.0);
      }
    }
    return values;
  }
}

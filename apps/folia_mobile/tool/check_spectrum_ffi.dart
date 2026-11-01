import 'dart:ffi';
import 'dart:io';

import 'package:folia_mobile/audio/analysis/spectrum_reader.dart';
import 'package:folia_mobile/audio/analysis/spectrum_snapshot.dart';

// Verify the real Dart/C ABI layout and buffer ownership using the host-only fixture, not a channel mock.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Pass the host analysis fixture shared library');
  }
  final library = DynamicLibrary.open(args.single);
  final begin = library.lookupFunction<Void Function(), void Function()>(
    'folia_fixture_begin',
  );
  final stop = library.lookupFunction<Void Function(), void Function()>(
    'folia_fixture_stop',
  );
  final reader = SpectrumReader.open(library: library),
      snapshot = SpectrumSnapshot();
  begin();
  try {
    var received = false;
    for (var i = 0; i < 200 && !received; i++) {
      received = reader.sample(snapshot);
      if (!received) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
    if (!received ||
        snapshot.sequence == 0 ||
        snapshot.sampleRate != 48000 ||
        snapshot.binCount != 1024 ||
        snapshot.bins[0] != 255) {
      throw StateError('Native spectrum frame/layout mismatch');
    }
    stop();
    final sequence = snapshot.sequence;
    if (reader.sample(snapshot) || snapshot.sequence != sequence) {
      throw StateError('Inactive reader mutated its frame');
    }
    reader.close();
    reader.close();
    if (reader.sample(snapshot) || snapshot.bins[0] != 255) {
      throw StateError('Dart data must survive native-buffer release');
    }
    snapshot.idle(2000);
    if (snapshot.binCount != 0 ||
        snapshot.bands.any((v) => v != idleBreath(2000))) {
      throw StateError('Original idle breath');
    }
    stdout.writeln(
      'Dart/C ABI, inactive reads, idle breath and snapshot ownership passed.',
    );
  } finally {
    stop();
    reader.close();
  }
}

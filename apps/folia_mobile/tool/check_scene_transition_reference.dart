import 'dart:convert';
import 'dart:io';

import 'package:folia_mobile/visualizer/transitions/scene_layers.dart';

// Minimal pure state differential check: no emulator, screenshot suite or timed UI test.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/scene_transition_reference.json').readAsStringSync(),
  ) as Map;
  List<SceneLayer<String>> decode(List<dynamic> input) => [
    for (final layer in input)
      SceneLayer(
        key: layer['key'],
        value: layer['value'],
        leaving: layer['leaving'],
        comesIn: layer['comesIn'],
        waits: layer['waits'],
      ),
  ];
  Object encode(List<SceneLayer<String>> layers) =>
      layers.map((layer) => layer.toJson()).toList();
  for (final row in fixture['cases']) {
    final next = nextShownLayers(
      decode(row['layers']),
      row['value'] as String,
      row['animate'] as bool,
      row['waits'] as bool,
    );
    if (jsonEncode(encode(next)) != jsonEncode(row['expected'])) {
      throw StateError('Original layer state mismatch: $row');
    }
    for (final start in row['starts']) {
      if (jsonEncode(encode(startedLayers(next, start['key']))) !=
          jsonEncode(start['expected'])) {
        throw StateError('Original first-frame state mismatch: $start');
      }
    }
  }
  stdout.writeln(
    '${fixture['cases'].length} original transition states matched; full visual parity is not certified.',
  );
}

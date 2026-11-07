import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_tile_view.dart';

// Two original-CSS elementFromPoint observations extend the existing real-wall case. The popped face is clickable beyond its seat; poster padding still hovers without activating the article.
Future<void> checkWallTileInput(
  WidgetTester tester, {
  required List<String> activations,
  required String slotKey,
  required Future<void> Function(bool poster) mount,
  required void Function(double) setNow,
  required VoidCallback tick,
}) async {
  final cases =
      jsonDecode(
            File('test/fixtures/wall_gradient_reference.json')
                .readAsStringSync(),
          )['hitCases']
          as List;
  final topLeft = tester.getTopLeft(find.byType(BravaisTileView).first),
      center = topLeft + const Offset(64, 64),
      mouse = await tester.createGesture(kind: PointerDeviceKind.mouse),
      expected = <String>[];
  await mouse.addPointer(location: center);
  await mouse.moveTo(center);
  await tester.pump();
  setNow(1000);
  tick();
  await tester.pump();
  for (final row in cases) {
    if (row['poster']) await mount(true);
    final point = row['point'] as List;
    await tester.tapAt(
      topLeft +
          Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
    );
    if (row['onFace']) expected.add(slotKey);
    expect(activations, expected, reason: 'original CSS hit $row');
  }
  await mouse.removePointer();
}

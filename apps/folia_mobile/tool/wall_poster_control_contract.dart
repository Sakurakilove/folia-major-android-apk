import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/rendering/folia_icons.dart';
import 'package:folia_mobile/library/bravais/poster/bravais_poster_button.dart';
import 'package:folia_mobile/library/wall/wall_typography.dart';

// Extend the existing card case with a source CTA's style targets and one real click/minimum box. This does not accept text metrics, all focus/hover pixels or complete pages.
Future<void> checkWallPosterControl(
  WidgetTester tester,
  FoliaIconData icon,
) async {
  final reference = jsonDecode(
    File('test/fixtures/poster_control_reference.json').readAsStringSync(),
  );
  const palette = BravaisPosterButtonPalette();
  for (final row in reference['cases']) {
    final input = row['input'],
        style = BravaisPosterButtonStyle(
          palette: palette,
          album: input['album'],
          primary: input['primary'],
          hovered: input['hovered'],
        ),
        expected = row['style'];
    void color(Color actual, dynamic wanted) {
      final values = [actual.r, actual.g, actual.b, actual.a];
      expect(
        [for (final v in values) double.parse(v.toStringAsPrecision(6))],
        [
          for (final v in wanted)
            double.parse((v as num).toStringAsPrecision(6)),
        ],
        reason: '$input',
      );
    }

    color(style.background, expected['background']);
    color(style.border, expected['border']);
    color(style.ink, expected['ink']);
    if (expected['shadow'] == null) {
      expect(style.shadow.a, 0);
    } else {
      color(style.shadow, expected['shadow']);
    }
    expect(style.borderWidth, expected['borderWidth']);
    expect(style.weight, expected['weight']);
  }
  var calls = 0;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: BravaisPosterButton(
          label: 'Play All',
          icon: icon,
          onPressed: () => calls++,
          typography: const WallTypography(),
          album: true,
          primary: true,
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.getSize(find.byType(BravaisPosterButton)).height, 46);
  await tester.tap(find.byType(BravaisPosterButton));
  expect(calls, 1);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/bravais_frame.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_poster_safe_layer.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_content_motion.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_level.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_paper.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_scene.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_viewport.dart';
import 'package:folia_mobile/library/bravais/tiles/bravais_card_palette.dart';
import 'package:folia_mobile/library/wall/wall_paint_boundary.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';

// The existing seam case now mounts its actual viewport/paper/body. Check retained width, clipping, bottom binding and the original safe-area rounding, without another UI suite.
Future<void> checkWallSeamViewport(
  WidgetTester tester, {
  required BravaisSeamContentMotion<Map<String, Object>> motion,
  required VoidCallback tick,
  required void Function(double) setNow,
  required int Function() listeners,
}) async {
  var builds = 0, presses = 0;
  BravaisFrame frameAt({
    double width = 300,
    bool poster = false,
    double x = 0,
  }) => computeBravaisFrame(
    center: WallPoint(x, 0),
    view: const WallView(800, 844, 1),
    anchorX: 0,
    openWidth: width,
    contentWidth: poster ? 520 : 300,
    hidden: false,
    poster: poster,
    tiltDeg: poster ? -10 : 0,
  );
  final frame = ValueNotifier(frameAt()),
      bottom = ValueNotifier(40.0),
      paper = BravaisSeamPaper(
        palette: const BravaisCardPalette(
          background: Color(0xff070707),
          ink: Color(0xfff7f4ee),
          accent: Color(0xfffd5c47),
          secondary: Color(0xff6a48ff),
          daylight: false,
        ),
      );
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 800,
          height: 844,
          child: BravaisSeamScene(
            motion: motion,
            frame: frame,
            viewportWidth: 800,
            bottom: bottom,
            surfaceFor: (_) => paper,
            contentBuilder: (_, shown) {
              builds++;
              return BravaisPosterSafeLayer(
                frame: frame,
                targetWidth: 520,
                viewportHeight: 844,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => presses++,
                  child: Text(shown.layerKey ?? ''),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  final built = builds,
      viewport = tester.renderObject<RenderBravaisSeamViewport>(
        find.byType(BravaisSeamViewport),
      ),
      body = tester.renderObject<RenderWallPaintBoundary>(
        find.byType(WallPaintBoundary),
      );
  expect(body.size, const Size(300, 804));
  frame.value = frameAt(width: 180);
  setNow(1100);
  tick();
  await tester.pump();
  expect(builds, built);
  expect(body.size, const Size(300, 804));
  expect(viewport.paperBounds, const Rect.fromLTWH(310, 0, 180, 844));
  expect(viewport.contentOffset, const Offset(250, 0));
  setNow(1210);
  tick();
  await tester.pump();
  expect(builds, built + 1);
  setNow(1450);
  tick();
  await tester.pump();
  expect(listeners(), 0);
  await tester.tapAt(const Offset(260, 100));
  expect(presses, 0);
  await tester.tapAt(const Offset(400, 100));
  expect(presses, 1);
  final retainedBuilds = builds;
  bottom.value = 80;
  await tester.pump();
  expect(body.size, const Size(300, 764));
  expect(builds, retainedBuilds);
  setNow(1500);
  motion.update(
    const BravaisRenderedSeam(BravaisSeamVariant.poster, 'K', {'key': 'K'}),
    reducedTransitions: false,
    hasElement: true,
  );
  setNow(1660);
  tick();
  frame.value = frameAt(width: 520, poster: true);
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(viewport.paperBounds.top, closeTo(-337.6, 1e-10));
  expect(viewport.paperBounds.height, closeTo(1519.2, 1e-10));
  expect(body.size, const Size(520, 764));
  final safe = tester.renderObject<RenderBravaisPosterSafe>(
        find.byType(BravaisPosterSafeLayer),
      ),
      matrix = safe.transform;
  final refs = jsonDecode(
        File('test/fixtures/wall_reference.json').readAsStringSync(),
      ),
      expected = (refs['frameCases'] as List).firstWhere(
        (row) => row['input']['tiltDeg'] == -10,
      )['safe'],
      scale = double.parse(
        (expected['scale'] as num).toDouble().toStringAsFixed(4),
      ),
      y = double.parse(
        (expected['offsetY'] as num).toDouble().toStringAsFixed(1),
      );
  expect(
    MatrixUtils.transformPoint(matrix, const Offset(520, 0)),
    Offset(520, y),
  );
  expect(
    MatrixUtils.transformPoint(matrix, Offset.zero).dx,
    closeTo(520 * (1 - scale), 1e-10),
  );
  frame.value = frameAt(width: 520, poster: true, x: 20);
  await tester.pump();
  expect(identical(matrix, safe.transform), true);
  setNow(1900);
  tick();
  await tester.pump();
  expect(listeners(), 0);
  await tester.pumpWidget(const SizedBox());
  frame.dispose();
  bottom.dispose();
  paper.dispose();
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/bravais_camera.dart';
import 'package:folia_mobile/library/bravais/display/bravais_wall_data.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_content_motion.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_level.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_opening.dart';
import 'package:folia_mobile/library/bravais/seam/bravais_seam_target.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_wall_shape.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';

import 'wall_seam_viewport_contract.dart';

// Extend one existing card check with actual original seam effect traces, finite opening ownership and one retained native layer; not a UI/focus/pixel suite.
Future<void> checkWallSeam(WidgetTester tester) async {
  final data = jsonDecode(
    File('test/fixtures/seam_reference.json').readAsStringSync(),
  );
  for (final row in data['targets']) {
    final input = row['input'];
    final options = BravaisSeamTargetInput(
          surface: BravaisLayerSurface.values.byName(input['surface']),
          level: BravaisSeamLevel.values.byName(input['level']),
          viewportWidth: (input['viewportWidth'] as num).toDouble(),
          formOpen: input['formOpen'] ?? false,
          panelOpen: input['panelOpen'] ?? false,
          filterOpen: input['filterOpen'] ?? false,
          searchOpen: input['searchOpen'] ?? false,
          poster: input['poster'] ?? false,
        ),
        target = BravaisSeamTarget.resolve(options);
    expect(target.width, row['target']['width']);
    expect(target.variant.wireName, row['target']['variant']);
    expect(options.effectiveLevel.name, row['effective']);
  }
  var level = const BravaisSeamLevelState(
    BravaisSeamLevel.full,
    BravaisSeamLevel.full,
  );
  for (var i = 0; i < (data['operations'] as List).length; i++) {
    final op = data['operations'][i];
    level = switch (op['kind']) {
      'apply' => level.apply(BravaisSeamLevel.values.byName(op['value'])),
      'restore' => level.restore(),
      _ => level.resize(
        (op['from'] as num).toDouble(),
        (op['to'] as num).toDouble(),
      ),
    };
    expect({
      'level': level.level.name,
      'restoreLevel': level.restoreLevel.name,
    }, data['states'][i]);
  }
  final clock = _Frames();
  var now = 0.0;
  final motion = BravaisSeamContentMotion<Map<String, Object>>(
    frames: clock,
    nowMs: () => now,
    initial: const BravaisRenderedSeam(BravaisSeamVariant.home, 'A', {
      'key': 'A',
      'revision': 1,
    }),
  );
  for (var i = 0; i < (data['motions']['operations'] as List).length; i++) {
    final op = data['motions']['operations'][i];
    now = (op['time'] as num).toDouble();
    if (op.containsKey('key')) {
      final key = op['key'] as String?;
      motion.update(
        BravaisRenderedSeam(
          BravaisSeamVariant.values.firstWhere(
            (v) => v.wireName == op['variant'],
          ),
          key,
          key == null ? null : {'key': key, 'revision': op['revision'] ?? 1},
        ),
        reducedTransitions: op['reduced'] ?? false,
        hasElement: op['hasElement'] ?? true,
      );
    } else {
      clock.tick();
    }
    final shown = motion.content.value;
    expect(
      {
        'key': shown.layerKey,
        'revision': shown.layer?['revision'],
        'variant': shown.variant.wireName,
        'leaving': motion.leaving,
        'phase': motion.phase?.name,
      },
      data['motions']['states'][i],
      reason: 'original seam step $i',
    );
  }
  expect(clock.count, 0);
  motion.update(
    const BravaisRenderedSeam(BravaisSeamVariant.full, 'K', {
      'key': 'K',
      'revision': 1,
    }),
    reducedTransitions: false,
    hasElement: true,
  );
  await checkWallSeamViewport(
    tester,
    motion: motion,
    frames: clock,
    nowMs: () => now,
    tick: clock.tick,
    setNow: (value) => now = value,
    listeners: () => clock.count,
  );
  motion.dispose();

  now = 0;
  final camera = BravaisCamera(
        frames: clock,
        nowMs: () => now,
        view: const WallView(1440, 900, .76),
        center: const WallPoint(0, 0),
        anchorX: -4,
        contentWidth: 300,
      ),
      opening = BravaisSeamOpening(
        frames: clock,
        nowMs: () => now,
        camera: camera,
        getShape: () => bravaisBlockShape,
        layerKey: 'A',
        target: const BravaisSeamTarget(300, BravaisSeamVariant.full),
      );
  expect(clock.count, 1);
  now = 180;
  clock.tick();
  expect(camera.openWidth, closeTo(150, 1e-7));
  now = 360;
  clock.tick();
  expect(camera.openWidth, 300);
  expect(clock.count, 0);
  opening.update(
    layerKey: 'A',
    target: const BravaisSeamTarget(662, BravaisSeamVariant.poster),
    reducedMotion: false,
  );
  now = 400;
  clock.tick();
  expect(camera.tiltDeg, 0);
  now = 600;
  clock.tick();
  expect(camera.tiltDeg, lessThan(0));
  opening.setActive(false);
  camera.setActive(false);
  expect(clock.count, 0);
  now = 3000;
  camera.setActive(true);
  opening.setActive(true);
  expect(camera.openWidth, 662);
  expect(camera.tiltDeg, -10);
  expect(clock.count, 0);
  opening.dispose();
  camera.dispose();
  clock.dispose();
}

class _Frames extends ChangeNotifier {
  int count = 0;
  @override
  void addListener(VoidCallback listener) {
    count++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    count--;
    super.removeListener(listener);
  }

  void tick() => notifyListeners();
}

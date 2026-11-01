import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/bravais_frame.dart';
import 'package:folia_mobile/library/bravais/bravais_reflow.dart';
import 'package:folia_mobile/library/bravais/bravais_viewport.dart';
import 'package:folia_mobile/library/wall/input/wall_pointer_pan.dart';
import 'package:folia_mobile/library/wall/wall_pan_motion.dart';
import 'package:folia_mobile/library/wall/wall_slots.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';

// Small headless contracts for actual source-hook input traces and retained native camera painting; not UI/pixel acceptance.
class _Clock extends ChangeNotifier {
  int count = 0;
  @override
  void addListener(VoidCallback callback) {
    count++;
    super.addListener(callback);
  }

  @override
  void removeListener(VoidCallback callback) {
    count--;
    super.removeListener(callback);
  }

  void tick() => notifyListeners();
}

void _equal(dynamic actual, dynamic expected, String at) {
  if (actual is num && expected is num && (actual - expected).abs() < 1e-8) {
    return;
  }
  if (actual is List && expected is List && actual.length == expected.length) {
    for (var i = 0; i < actual.length; i++) {
      _equal(actual[i], expected[i], '$at[$i]');
    }
    return;
  }
  if (actual is Map && expected is Map && actual.length == expected.length) {
    for (final key in expected.keys) {
      _equal(actual[key], expected[key], '$at.$key');
    }
    return;
  }
  expect(actual, expected, reason: at);
}

void main() {
  test('original pointer hook trace, immediate Android pan, finite frames and ownership', () {
    final reference = (jsonDecode(
          File('test/fixtures/wall_reference.json').readAsStringSync(),
        ) as Map)['pointer'],
        clock = _Clock(),
        writes = <Map<String, Object>>[],
        commits = <double>[];
    var now = 0.0, camera = const WallCamera(0, 0, .52);
    final pan = WallPointerPan(
      frames: clock,
      nowMs: () => now,
      readCamera: () => camera,
      applyCamera: (value, cull) {
        camera = value;
        writes.add({'camera': value.toJson(), 'updateBounds': cull});
      },
      worldBounds: (c) => WallBounds(c.x, c.x + 390, c.y, c.y + 844),
      readCullBounds: () =>
          const WallBounds(-1000000, 1000000, -1000000, 1000000),
      viewportHeight: () => 844,
      stopExternalAnimation: () {},
      overscan: 300,
      onScaleCommit: commits.add,
    );
    final List operations = reference['operations'];
    for (var i = 0; i < operations.length; i++) {
      final Map op = operations[i];
      if (op['t'] != null) now = (op['t'] as num).toDouble();
      final event = WallPointerSample(
        op['id'] ?? 0,
        (op['x'] as num? ?? 0).toDouble(),
        (op['y'] as num? ?? 0).toDouble(),
        now,
        touch: op['touch'] ?? false,
        primary: op['primary'] ?? true,
        control: op['control'] ?? false,
        editable: op['editable'] ?? false,
      );
      switch (op['kind']) {
        case 'down':
          pan.pointerDown(event);
        case 'move':
          pan.pointerMove(event);
        case 'up':
          pan.pointerUp(event);
        case 'cancel':
          pan.pointerCancel(event);
        case 'tick':
          clock.tick();
        case 'click':
          pan.consumeClick(keyboard: op['keyboard'] ?? false);
        case 'blur':
          pan.cancel();
        case 'wheel':
          pan.wheel(
            WallWheelSample(
              (op['dx'] as num).toDouble(),
              (op['dy'] as num).toDouble(),
              now,
              shift: op['shift'] ?? false,
            ),
            ctrl: op['ctrl'] ?? false,
          );
      }
      _equal(
        {
          'writes': writes.length,
          'camera': camera.toJson(),
          'didDrag': pan.didDrag,
          'commits': commits,
        },
        reference['states'][i],
        'operation $i ${op['kind']}',
      );
      if (i == 2) {
        expect(camera.x, 8);
        expect(clock.count, 0);
      }
    }
    _equal(writes, reference['writes'], 'source camera writes');
    expect(clock.count, 0);
    pan.pointerDown(const WallPointerSample(10, 0, 0, 2000, touch: true));
    pan.pointerMove(const WallPointerSample(10, 100, 0, 2016, touch: true));
    now = 2016;
    pan.pointerUp(const WallPointerSample(10, 100, 0, 2017, touch: true));
    expect(clock.count, 1);
    now = 5016;
    clock.tick();
    expect(clock.count, 0);
    pan.wheel(const WallWheelSample(0, 100, 6000));
    expect(clock.count, 1);
    pan.setActive(false);
    expect(clock.count, 0);
    final previous = writes.length;
    clock.tick();
    expect(writes.length, previous);
    pan.dispose();
    clock.dispose();
  });
  test(
    'interrupted focus reflows retain source rectangles and release clock',
    () {
      final reference = jsonDecode(
            File('test/fixtures/wall_reference.json').readAsStringSync(),
          ) as Map,
          clock = _Clock();
      var now = 0.0;
      WallRect rect(WallSlot s) => WallRect(s.x, s.y, s.width, s.height);
      final reflow = BravaisReflow(
        frames: clock,
        nowMs: () => now,
        resting: (key) {
          final a = parseWallSlotKey(key);
          return a == null
              ? null
              : rect(wallSlot(a.column, a.row, a.slotIndex, bravaisMetrics)!);
        },
      );
      for (final operation in reference['plates']['reflowOperations']) {
        now = (operation['time'] as num).toDouble();
        if (operation['kind'] == 'target') {
          final int? index = operation['index'];
          reflow.updateTargets(
            index == null
                ? {}
                : {
                    for (final s in layoutFocusedBlock(
                      0,
                      0,
                      index,
                      bravaisMetrics,
                    )!)
                      s.key: rect(s),
                  },
          );
        } else {
          clock.tick();
        }
        _equal(
          reflow.value.entries.map((e) => [e.key, e.value.toJson()]).toList(),
          operation['rects'],
          'focus reflow at $now',
        );
        expect(reflow.animating, operation['animating']);
      }
      expect(clock.count, 0);
      reflow.dispose();
      clock.dispose();
    },
  );
  testWidgets('camera frames retain poster layout and child layers', (
    tester,
  ) async {
    var layouts = 0, paints = 0;
    BravaisFrame makeFrame(double x) => computeBravaisFrame(
      center: WallPoint(x, 0),
      view: const WallView(390, 844, .52),
      anchorX: -4,
      openWidth: 120,
      contentWidth: 120,
      hidden: false,
    );
    final frame = ValueNotifier(makeFrame(0)),
        slot = wallSlot(0, 0, 0, bravaisMetrics)!;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 390,
            height: 844,
            child: BravaisViewport(
              frame: frame,
              dpr: 3,
              children: [
                BravaisSeat(
                  slot: slot,
                  child: RepaintBoundary(
                    child: _Counter(() => layouts++, () => paints++),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final initialLayouts = layouts, initialPaints = paints;
    for (final x in [5.0, 15.0, 25.0]) {
      frame.value = makeFrame(x);
      await tester.pump();
    }
    expect(layouts, initialLayouts);
    expect(paints, initialPaints);
    await tester.pumpWidget(const SizedBox());
    frame.dispose();
  });
}

class _Counter extends LeafRenderObjectWidget {
  const _Counter(this.layoutCount, this.paintCount);
  final VoidCallback layoutCount, paintCount;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCounter(layoutCount, paintCount);
}

class _RenderCounter extends RenderBox {
  _RenderCounter(this.layoutCount, this.paintCount);
  final VoidCallback layoutCount, paintCount;
  @override
  void performLayout() {
    layoutCount();
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    paintCount();
    context.canvas.drawRect(
      offset & size,
      Paint()..color = const Color(0xff336699),
    );
  }
}

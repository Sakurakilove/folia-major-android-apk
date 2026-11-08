import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_flight.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_flights.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_overlay.dart';
import 'package:folia_mobile/library/bravais/cover/bravais_cover_quad.dart';

// Extend the existing card case with original function traces and one actual retained cover layer; no emulator, full UI or visual acceptance claim.
Future<void> checkWallCoverFlights(WidgetTester tester) async {
  final reference = jsonDecode(
    File('test/fixtures/cover_flight_reference.json').readAsStringSync(),
  );
  BravaisCoverQuad quad(dynamic value) => BravaisCoverQuad(
    Offset(
      (value['center']['x'] as num).toDouble(),
      (value['center']['y'] as num).toDouble(),
    ),
    (value['width'] as num).toDouble(),
    (value['height'] as num).toDouble(),
    (value['angle'] as num).toDouble(),
  );
  for (final row in reference['sizes']) {
    final result = bravaisDrawnCoverSize(
      row['size'],
      (row['width'] as num).toDouble(),
      (row['height'] as num).toDouble(),
    );
    expect([result.width, result.height], row['result']);
  }
  for (final row in reference['offsets']) {
    expect(
      bravaisCoverOffset(row['token'], (row['free'] as num).toDouble()),
      row['result'],
    );
  }
  for (final row in reference['cases']) {
    final frames = _CoverFrames();
    var now = 0.0, done = 0, reads = 0;
    var ready = false, lost = false;
    var target = quad(row['initialTarget']);
    final flights = BravaisCoverFlights(frames: frames, nowMs: () => now),
        flight = flights.fly(
          url: 'https://example.com/cover.jpg',
          from: quad(row['from']),
          target: () => target,
          duration: row['name'] == 'fade' ? 560 : 640,
          shadowFrom: const BravaisCoverShadow(2, Color(0xff112233)),
          shadowTo: (q) =>
              BravaisCoverShadow(q.width / 40, const Color(0xffaabbcc)),
          landing: row['name'] == 'fade'
              ? BravaisCoverLanding.fade
              : BravaisCoverLanding.swap,
          ready: () {
            reads++;
            return ready;
          },
          lost: () => lost,
          onDone: () => done++,
        );
    try {
      for (final step in row['steps']) {
        now = (step['at'] as num).toDouble();
        if (step['target'] != null) {
          target = quad(
            step['target'] == 'moved'
                ? row['movedTarget']
                : row['initialTarget'],
          );
          ready = step['ready'];
          lost = step['lost'];
        }
        if (step['op'] != 'start') frames.tick();
        if (step['op'] == 'stop') flights.stop();
        final expected = step['expected'],
            sample = flight.frame,
            q = sample.quad;
        void numbers(List<double> actual, List<dynamic> wanted) {
          for (var i = 0; i < actual.length; i++) {
            expect(
              actual[i],
              closeTo((wanted[i] as num).toDouble(), 1e-9),
              reason: '${row['name']} ${step['at']} component $i',
            );
          }
        }

        numbers([
          q.center.dx,
          q.center.dy,
          q.width,
          q.height,
          q.angle,
        ], expected['quad']);
        expect(sample.scale, closeTo(expected['scale'], 1e-12));
        expect(sample.hard.offset, closeTo(expected['hard'][0], 1e-12));
        final color = expected['hard'][1] == '#112233'
            ? const Color(0xff112233)
            : const Color(0xffaabbcc);
        expect(
          sample.hard.color,
          color.withValues(alpha: (expected['hard'][2] as num).toDouble()),
        );
        numbers([
          sample.softOffset.dx,
          sample.softOffset.dy,
          sample.softBlur,
          sample.softAlpha,
        ], expected['soft']);
        expect(done, expected['done']);
        expect(reads, expected['reads']);
        expect(flight.removed, expected['removed']);
      }
      expect(flights.entries.value, isEmpty);
      expect(frames.count, 0);
    } finally {
      flights.dispose();
      frames.dispose();
    }
  }
  await _checkCoverLayer(tester);
}

Future<void> _checkCoverLayer(WidgetTester tester) async {
  var now = 0.0, done = 0;
  final clock = _CoverFrames(),
      flights = BravaisCoverFlights(frames: clock, nowMs: () => now);
  var builds = 0;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: BravaisCoverOverlay(
        flights: flights,
        imageFor: (_) {
          builds++;
          return null;
        },
      ),
    ),
  );
  final flight = flights.fly(
    url: 'source',
    from: const BravaisCoverQuad(Offset(50, 120), 128, 240, 3.05),
    target: () => const BravaisCoverQuad(Offset(390, 450), 320, 320, -3.05),
    duration: 640,
    shadowFrom: BravaisCoverShadow.none,
    shadowTo: (_) => const BravaisCoverShadow(8, Color(0xffaabbcc)),
    landing: BravaisCoverLanding.swap,
    onDone: () => done++,
  );
  await tester.pump();
  final layer = tester.renderObject<RenderBravaisCoverFlight>(
    find.byKey(ObjectKey(flight)),
  );
  final child = layer.child;
  now = 40;
  clock.tick();
  await tester.pump();
  flights.setActive(false);
  await tester.pump();
  expect(clock.count, 0);
  expect(identical(layer.child, child), true);
  now = 60;
  flights.setActive(true);
  await tester.pump();
  expect(clock.count, 1);
  expect(builds, 1);
  for (final at in [80.0, 160.0, 320.0, 480.0, 640.0]) {
    now = at;
    clock.tick();
    await tester.pump();
    expect(identical(layer.child, child), true);
    expect(builds, 1);
    expect(
      child!.size,
      Size(flight.frame.quad.width, flight.frame.quad.height),
    );
    expect(tester.takeException(), isNull);
  }
  expect(done, 1);
  expect(
    flights.entries.value.length,
    1,
  ); // Same-frame swap retains the flying cover.
  now = 656;
  clock.tick();
  await tester.pump();
  expect(flights.entries.value, isEmpty);
  expect(clock.count, 0);
  // Return waits only while the tile can reappear; a still-connected cover aborts.
  flights.back(
    reducedMotion: false,
    coverConnected: () => false,
    from: const BravaisCoverQuad(Offset.zero, 128, 128, 0),
    shadow: BravaisCoverShadow.none,
    cardKey: 'album',
    coverUrl: 'source',
    findTile: () => null,
  );
  now = 1556;
  clock.tick();
  expect(clock.count, 0);
  flights.back(
    reducedMotion: false,
    coverConnected: () => true,
    from: const BravaisCoverQuad(Offset.zero, 128, 128, 0),
    shadow: BravaisCoverShadow.none,
    cardKey: 'album',
    coverUrl: 'source',
    findTile: () => throw StateError('must not look up a tile'),
  );
  now = 1572;
  clock.tick();
  expect(clock.count, 0);
  flights.fly(
    url: 'never-mounted',
    from: const BravaisCoverQuad(Offset.zero, 128, 128, 0),
    target: () => null,
    duration: 640,
    shadowFrom: BravaisCoverShadow.none,
    shadowTo: (_) => BravaisCoverShadow.none,
    landing: BravaisCoverLanding.swap,
    deferred: true,
    lost: () => throw StateError('A prepared flight has no target layout yet'),
  );
  expect(clock.count, 0);
  flights.stop();
  expect(clock.count, 1);
  clock.tick();
  expect(clock.count, 0);
  expect(flights.entries.value, isEmpty);
  await tester.pumpWidget(const SizedBox());
  flights.dispose();
  clock.dispose();
}

class _CoverFrames extends ChangeNotifier {
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

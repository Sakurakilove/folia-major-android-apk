import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/wall/reveal_rect.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';
import 'package:folia_mobile/library/bravais/bravais_key_model.dart';
import 'package:folia_mobile/library/bravais/bravais_home_keys.dart';
import 'package:folia_mobile/library/bravais/bravais_poster_reveal.dart';

// Pure original key/reveal observations share the existing card case. Device key routing, IME, actual focus commit timing and final pixels remain pending.
void checkWallKeysAndReveal(Map data) {
  BravaisKeyInput key(Map m) => BravaisKeyInput(
    m['key'],
    shiftKey: m['shiftKey'],
    altKey: m['altKey'],
    ctrlKey: m['ctrlKey'],
    metaKey: m['metaKey'],
    repeat: m['repeat'],
  );
  for (final row in data['keys']) {
    expect(
      resolveBravaisKey(key(row['input']))?.toJson(),
      row['common'],
      reason: '${row['input']}',
    );
    expect(
      resolveBravaisHomeKey(key(row['input']))?.toJson(),
      row['home'],
      reason: '${row['input']}',
    );
    expect(
      resolveBravaisWallKey(key(row['input']))?.toJson(),
      row['common'] ?? row['home'],
    );
  }
  for (final row in data['escapes']) {
    final m = row['input'];
    expect(
      resolveBravaisEscapeStep(
        hasForm: m['hasForm'],
        hasFocusCard: m['hasFocusCard'],
        hasKeyboardFocus: m['hasKeyboardFocus'],
        hasPanel: m['hasPanel'],
        hasViewMode: m['hasViewMode'],
        hasQuery: m['hasQuery'],
        canGoBack: m['canGoBack'],
      )?.value,
      row['result'],
    );
  }
  for (final row in data['typing']) {
    expect(
      resolveBravaisTypingKey(
        key(row['input']),
        reserved: List<String>.from(row['reserved']),
      )?.name,
      row['result'],
    );
  }
  double d(dynamic n) => (n as num).toDouble();
  WallPoint point(Map m) => WallPoint(d(m['x']), d(m['y']));
  WallView view(Map m) => WallView(
    d(m['width']),
    d(m['height']),
    d(m['scale']),
    lineX: (m['lineX'] as num?)?.toDouble(),
  );
  WallRect rect(Map m) =>
      WallRect(d(m['x']), d(m['y']), d(m['width']), d(m['height']));
  void numbers(Map<String, double> actual, Map expected) {
    expect(actual.keys.toSet(), expected.keys.toSet());
    for (final entry in actual.entries) {
      expect(
        entry.value,
        closeTo(d(expected[entry.key]), 1e-9),
        reason: '${entry.key}:$expected',
      );
    }
  }

  for (final row in data['ordinaryReveal']) {
    final m = row['input'], metrics = m['metrics'];
    numbers(
      resolveWallRevealCenter(
        rect: rect(m['rect']),
        center: point(m['center']),
        view: view(m['view']),
        metrics: WallMetrics(d(metrics['cellSize']), d(metrics['gap'])),
        anchorX: (m['anchorX'] as num?)?.toDouble(),
        seamWidth: d(m['seamWidth']),
        pad: d(m['pad']),
        bottomInset: d(m['bottomInset']),
        centered: m['centered'],
      ).toJson(),
      row['result'],
    );
  }
  for (final row in data['posters']) {
    final input = row['input'],
        f = input['frame'],
        frame = BravaisRevealFrame(
          center: point(f['center']),
          view: view(f['view']),
          anchorX: (f['anchorX'] as num?)?.toDouble(),
          openWidth: d(f['openWidth']),
          contentWidth: d(f['contentWidth']),
          hidden: f['hidden'],
          poster: f['poster'],
          tiltDeg: d(f['tiltDeg']),
        ),
        box = rect(input['rect']);
    numbers(bravaisPosterScreenBox(box, frame).toJson(), row['box']);
    numbers(
      resolveBravaisPosterRevealCenter(
        rect: box,
        frame: frame,
        posterWidth: d(input['posterWidth']),
        pad: d(input['pad']),
        bottomInset: d(input['bottomInset']),
      ).toJson(),
      row['result'],
    );
  }
}

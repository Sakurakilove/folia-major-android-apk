import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/library/bravais/bravais_poster_reveal.dart';
import 'package:folia_mobile/library/bravais/shape/bravais_wall_shape.dart';
import 'package:folia_mobile/library/bravais/stage/bravais_focus_model.dart';
import 'package:folia_mobile/library/wall/wall_types.dart';

// Actual original hook trace: refs update immediately, drawn reflow only at the next render commit. This is not complete focus/IME/navigation or a device pixel acceptance.
void checkWallFocus(Map data) {
  final initial = data['frame'],
      v = initial['view'],
      view = WallView(
        (v['width'] as num).toDouble(),
        (v['height'] as num).toDouble(),
        (v['scale'] as num).toDouble(),
      ),
      slots = bravaisBlockShape.blockSlotsAt(0, 0),
      notes = <String?>[],
      tweens = <WallPoint>[];
  var ready = false, poster = false;
  final model = BravaisFocusModel(
    readFrame: () => !ready
        ? null
        : (
            frame: BravaisRevealFrame(
              center: WallPoint(
                (initial['center']['x'] as num).toDouble(),
                (initial['center']['y'] as num).toDouble(),
              ),
              view: view,
              anchorX: (initial['anchorX'] as num).toDouble(),
              openWidth: (initial['openWidth'] as num).toDouble(),
              contentWidth: (initial['contentWidth'] as num).toDouble(),
              hidden: initial['hidden'],
              poster: poster,
              tiltDeg: (initial['tiltDeg'] as num).toDouble(),
            ),
            targetOpenWidth: (initial['targetOpenWidth'] as num).toDouble(),
          ),
    getShape: () => bravaisBlockShape,
    getBottomInset: () => (data['bottomInset'] as num).toDouble(),
    onFocusEntry: notes.add,
    tweenTo: tweens.add,
  );
  void numbers(Map<String, double> actual, Map expected) {
    for (final entry in actual.entries) {
      expect(
        entry.value,
        closeTo((expected[entry.key] as num).toDouble(), 1e-9),
        reason: '$expected',
      );
    }
  }

  model.reflowForBuild(null, bravaisBlockShape);
  try {
    for (final step in data['steps']) {
      final command = step['command'];
      switch (command['op']) {
        case 'view-ready':
          ready = true;
        case 'poster':
          poster = true;
        case 'commit':
          model.reflowForBuild(model.value.expandedSlotKey, bravaisBlockShape);
        case 'focus':
          model.focusSlot(
            command['seat'] == null ? null : slots[command['seat']],
            revealSlot: command['reveal'] == true,
          );
        case 'expand':
          model.expand(
            slots[command['seat']],
            centered: command['centered'] == true,
          );
        case 'collapse':
          model.collapse();
        case 'reveal':
          model.reveal(
            model.drawnSlot(slots[command['seat']]),
            centered: command['centered'] == true,
          );
      }
      expect(model.value.focusedSlotKey, step['focused']);
      expect(model.value.expandedSlotKey, step['expanded']);
      expect(notes.length, step['notes']);
      expect(tweens.length, step['tweens']);
      expect(notes.lastOrNull, step['lastNote']);
      if (step['lastTween'] != null) {
        numbers(tweens.last.toJson(), step['lastTween']);
      }
      for (var i = 0; i < 3; i++) {
        final drawn = model.drawnSlot(slots[i]);
        numbers({
          'x': drawn.x,
          'y': drawn.y,
          'width': drawn.width,
          'height': drawn.height,
        }, step['drawn'][i]);
      }
    }
  } finally {
    model.dispose();
  }
}

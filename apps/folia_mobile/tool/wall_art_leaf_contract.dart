import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/artwork/wall_artwork_image.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_art_effect.dart';
import 'package:folia_mobile/library/bravais/tiles/artwork/bravais_art_style.dart';

// Same focused art case: both native subscriptions suspend at zero opacity/hidden TickerMode, then resume the retained completers without reloading.
Future<void> checkWallArtLeaf(
  WidgetTester tester, {
  required ui.Image foreground,
  required ui.Image background,
  required BravaisArtEffect effect,
  required ValueNotifier<BravaisArtStyle> style,
}) async {
  final front = _LeafImage(foreground), back = _LeafImage(background);
  Widget scene(bool active) => Directionality(
    textDirection: TextDirection.ltr,
    child: TickerMode(
      enabled: active,
      child: SizedBox(
        width: 8,
        height: 8,
        child: WallArtworkImage(
          provider: front,
          underlay: back,
          effect: effect,
        ),
      ),
    ),
  );
  await tester.pumpWidget(scene(true));
  expect(front.active, 1);
  expect(back.active, 1);
  style.value = const BravaisArtStyle(
    mode: BravaisArtShaderMode.mosaic,
    opacity: 0,
  );
  await tester.pump();
  expect(front.active, 0);
  expect(back.active, 0);
  style.value = const BravaisArtStyle(mode: BravaisArtShaderMode.mosaic);
  await tester.pump();
  expect(front.active, 1);
  expect(back.active, 1);
  expect(front.loads, 1);
  expect(back.loads, 1);
  await tester.pumpWidget(scene(false));
  expect(front.active, 0);
  expect(back.active, 0);
  await tester.pumpWidget(scene(true));
  expect(front.active, 1);
  expect(back.active, 1);
  await tester.pumpWidget(const SizedBox());
  expect(front.active, 0);
  expect(back.active, 0);
}

class _LeafImage extends ImageProvider<String> {
  _LeafImage(this.image);
  final ui.Image image;
  int loads = 0, active = 0;
  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture('leaf:${identityHashCode(this)}');
  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    String key,
    ImageErrorListener handleError,
  ) {
    loads++;
    stream.setCompleter(_LeafCompleter(this));
  }
}

class _LeafCompleter extends OneFrameImageStreamCompleter {
  _LeafCompleter(this.owner)
    : super(SynchronousFuture(ImageInfo(image: owner.image.clone())));
  final _LeafImage owner;
  @override
  void addListener(ImageStreamListener listener) {
    owner.active++;
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    owner.active--;
    super.removeListener(listener);
  }
}

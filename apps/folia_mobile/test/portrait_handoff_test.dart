import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folia_mobile/monet/monet_portrait_image.dart';

// The source restarts the full fade duration on a changed target; reversing Flutter's progress shortens the interrupted fade.
class _DecodedPortrait extends ImageProvider<_DecodedPortrait> {
  const _DecodedPortrait(this.image);
  final ui.Image image;
  @override
  Future<_DecodedPortrait> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _DecodedPortrait key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future.value(ImageInfo(image: image.clone())),
  );
}

void main() {
  testWidgets(
    'clearing a portrait mid-fade retains its image and uses the full original 900ms fade',
    (tester) async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xffffffff), BlendMode.src);
      final picture = recorder.endRecording(),
          image = picture.toImageSync(2, 2),
          provider = _DecodedPortrait(image);
      picture.dispose();
      Widget frame(bool visible) => Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 200,
          child: MonetPortraitImage(
            image: visible ? provider : null,
            source: visible ? 'cover' : null,
          ),
        ),
      );
      await tester.pumpWidget(frame(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition))
            .opacity
            .value,
        closeTo(.5, .001),
      );
      await tester.pumpWidget(frame(false));
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition))
            .opacity
            .value,
        closeTo(.25, .001),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition))
            .opacity
            .value,
        0,
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await provider.evict();
      image.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}

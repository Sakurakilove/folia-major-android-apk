import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:folia_mobile/artwork/wall_artwork_image.dart';
import 'package:folia_mobile/artwork/cover_url.dart';
import 'package:folia_mobile/artwork/native_artwork_buffer.dart';
import 'package:folia_mobile/artwork/native_artwork_descriptors.dart';
import 'package:folia_mobile/artwork/native_url.dart';
import 'package:folia_mobile/artwork/wall_artwork_queue.dart';
import 'package:folia_mobile/artwork/wall_artwork_store.dart';

// Focused native lifecycle check, explicitly run with host libraries; not part of a full UI suite or browser image/pixel acceptance.
// FOLIA_URL_LIBRARY=/tmp/libfolia_url.so FOLIA_ARTWORK_LIBRARY=/tmp/libfolia_artwork.so flutter test tool/check_artwork_images.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final urls = NativeUrlLibrary(
        library: DynamicLibrary.open(
          Platform.environment['FOLIA_URL_LIBRARY']!,
        ),
      ),
      native = DynamicLibrary.open(
        Platform.environment['FOLIA_ARTWORK_LIBRARY']!,
      ),
      descriptors = NativeArtworkDescriptors(library: native),
      createScope = native.lookupFunction<Uint64 Function(), int Function()>(
        'folia_artwork_create_scope',
      ),
      releaseScope = native
          .lookupFunction<Void Function(Uint64), void Function(int)>(
            'folia_artwork_release_scope',
          ),
      createFile = native.lookupFunction<Int32 Function(), int Function()>(
        'folia_artwork_memory_file',
      ),
      register = native
          .lookupFunction<Uint64 Function(Uint64, Int32), int Function(int, int)>(
            'folia_artwork_register',
          ),
      close = DynamicLibrary.process()
          .lookupFunction<Int32 Function(Int32), int Function(int)>('close'),
      bytes = File('test/fixtures/artwork_two_frames.gif').readAsBytesSync(),
      messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('folia/artwork-contract');
  test('native ticket buffer keeps complete multi-frame image and rejects stale owner', () async {
    final scope = createScope();
    var calls = 0, stale = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'open');
      expect(call.arguments['url'], contains('%7E'));
      calls++;
      final fd = createFile();
      expect(fd, greaterThanOrEqualTo(0));
      late int ticket;
      try {
        await File('/proc/self/fd/$fd').writeAsBytes(bytes);
        ticket = register(scope, fd);
      } finally {
        close(fd);
      }
      expect(ticket, greaterThan(0));
      if (stale) releaseScope(scope);
      return {'ticket': ticket};
    });
    final loader = NativeArtworkBufferLoader(
      urls: urls,
      channel: channel,
      descriptors: descriptors,
    );
    final buffer = await loader.load(
          'https://example.test/a%7E.gif',
          ArtworkCancellation(),
        ),
        codec = await ui.instantiateImageCodecFromBuffer(buffer);
    expect(codec.frameCount, 2);
    expect(codec.repetitionCount, -1);
    for (var i = 0; i < 2; i++) {
      final frame = await codec.getNextFrame();
      try {
        expect(frame.duration, Duration(milliseconds: i == 0 ? 80 : 120));
        final rgba = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        expect(
          rgba.buffer.asUint8List(),
          i == 0 ? [255, 0, 0, 255] : [0, 0, 255, 255],
        );
      } finally {
        frame.image.dispose();
      }
    }
    codec.dispose();
    final inline = await loader.load(
      'data:image/gif;base64,${base64Encode(bytes)}',
      ArtworkCancellation(),
    );
    expect(inline.length, bytes.length);
    inline.dispose();
    expect(calls, 1);
    stale = true;
    await expectLater(
      loader.load('https://example.test/a%7E.gif', ArtworkCancellation()),
      throwsA(isA<ArtworkCancelled>()),
    );
    expect(calls, 2);
    loader.dispose();
    releaseScope(scope);
    messenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'cancelling native preparation sends one discrete cancel, no image payload',
    () async {
      final pending = Completer<dynamic>(), started = Completer<void>();
      var cancels = 0;
      messenger.setMockMethodCallHandler(channel, (call) {
        if (call.method == 'open') {
          started.complete();
          return pending.future;
        }
        expect(call.method, 'cancel');
        expect((call.arguments as Map).keys, ['id']);
        cancels++;
        pending.completeError(PlatformException(code: 'cancelled'));
        return Future.value(null);
      });
      final loader = NativeArtworkBufferLoader(
            urls: urls,
            channel: channel,
            descriptors: descriptors,
          ),
          signal = ArtworkCancellation(),
          future = loader.load('https://example.test/a.gif', signal);
      final checked = expectLater(future, throwsA(isA<ArtworkCancelled>()));
      await started.future;
      signal.cancel();
      await checked;
      expect(cancels, 1);
      loader.dispose();
      messenger.setMockMethodCallHandler(channel, null);
    },
  );
  testWidgets(
    'shared decode survives one cancelled consumer and priming keeps first frame',
    (tester) async {
      final prepared = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes),
            red = await codec.getNextFrame(),
            blue = await codec.getNextFrame();
        codec.dispose();
        return (
          await ui.ImmutableBuffer.fromUint8List(bytes),
          red.image,
          blue.image,
        );
      });
      final buffer = prepared!.$1, red = prepared.$2, blue = prepared.$3;
      var loads = 0;
      late _Codec codec;
      final store = WallArtworkStore(
        policy: CoverUrlPolicy(urls),
        loadBuffer: (_, _) {
          loads++;
          return SynchronousFuture(buffer);
        },
        imageDecoder: (buffer, {getTargetSize}) {
          buffer.dispose();
          codec = _Codec(red, blue);
          return SynchronousFuture(codec);
        },
      );
      const url = 'https://example.test/a.gif';
      final stream = store.provider(url).resolve(ImageConfiguration.empty),
          frames = <String>[];
      final listener = ImageStreamListener((info, _) {
        frames.add(
          info.image.isCloneOf(red)
              ? 'red'
              : info.image.isCloneOf(blue)
              ? 'blue'
              : 'unexpected',
        );
        info.dispose();
      });
      stream.addListener(listener);
      final first = store.decodeVariant(url),
          signal = ArtworkCancellation(),
          second = store.decodeVariant(url, signal: signal);
      signal.cancel();
      var builds = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (_) {
              builds++;
              return SizedBox(
                width: 20,
                height: 20,
                child: WallArtworkImage(provider: store.provider(url)),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(await first, true);
      expect(await second, true);
      expect(loads, 1);
      expect(frames, ['red']);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump();
      expect(frames, ['red', 'blue']);
      expect(builds, 1);
      expect(
        tester
            .renderObject<RenderImage>(find.byType(WallArtworkImage))
            .image!
            .isCloneOf(blue),
        true,
      );
      expect(codec.reads, 2);
      stream.removeListener(listener);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      red.dispose();
      blue.dispose();
      expect(codec.disposals, 1);
      expect(store.queue.activeCount, 0);
    },
  );
}

class _Frame implements ui.FrameInfo {
  const _Frame(this.image, this.duration);
  @override
  final ui.Image image;
  @override
  final Duration duration;
}

class _Codec implements ui.Codec {
  _Codec(this.red, this.blue);
  final ui.Image red, blue;
  int reads = 0, disposals = 0;
  @override
  int get frameCount => 2;
  @override
  int get repetitionCount => 0;
  @override
  Future<ui.FrameInfo> getNextFrame() {
    final first = reads++ % 2 == 0;
    return SynchronousFuture(
      _Frame(
        (first ? red : blue).clone(),
        Duration(milliseconds: first ? 80 : 120),
      ),
    );
  }

  @override
  void dispose() {
    disposals++;
  }
}

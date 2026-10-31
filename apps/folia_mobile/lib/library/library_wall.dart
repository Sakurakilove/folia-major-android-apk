import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../rendering/repaint_signal.dart';

import 'package:flutter/scheduler.dart';

import '../playback/playback_controller.dart';

// Viewport-bounded native wall: stable world coordinates, no offscreen tile widgets or idle ticker.
class LibraryWall extends StatefulWidget {
  const LibraryWall({
    super.key,
    required this.tracks,
    required this.onSelect,
    this.active = true,
  });
  final bool active;
  final List<AudioTrack> tracks;
  final ValueChanged<int> onSelect;
  @override
  State<LibraryWall> createState() => _LibraryWallState();
}

class _LibraryWallState extends State<LibraryWall>
    with SingleTickerProviderStateMixin {
  final camera = RepaintSignal();
  Offset offset = const Offset(20, 20), velocity = Offset.zero;
  double scale = 1, lastGestureScale = 1;
  int pointers = 0;
  late final Ticker inertia = createTicker((elapsed) {
    final dt = (elapsed.inMicroseconds - _previousMicros) / 1e6;
    _previousMicros = elapsed.inMicroseconds;
    offset += velocity * dt;
    velocity *= math.exp(-4.2 * dt);
    camera.invalidate();
    if (velocity.distance < 1) inertia.stop();
  });
  int _previousMicros = 0;
  int imageBytes = 0;
  Set<String> pinnedImages = {};
  final images = <String, ui.Image>{},
      pending = <String>{},
      failed = <String>{};
  final labels = <String, TextPainter>{};
  final decodeQueue = Queue<String>();
  int decoding = 0;
  @override
  void didUpdateWidget(covariant LibraryWall old) {
    super.didUpdateWidget(old);
    if (!widget.active) {
      inertia.stop();
      for (final key in decodeQueue) {
        pending.remove(key);
      }
      decodeQueue.clear();
    }
  }

  void request(String path) {
    if (images.containsKey(path) ||
        failed.contains(path) ||
        !pending.add(path)) {
      return;
    }
    decodeQueue.add(path);
    scheduleMicrotask(_drain);
  }

  void _drain() {
    while (mounted && widget.active && decoding < 2 && decodeQueue.isNotEmpty) {
      final path = decodeQueue.removeFirst();
      if (!pinnedImages.contains(path)) {
        pending.remove(path);
        continue;
      }
      decoding++;
      _decode(path);
    }
  }

  void _decode(String path) {
    File(path)
        .readAsBytes()
        .then(ui.instantiateImageCodec)
        .then((codec) async {
          final frame = await codec.getNextFrame();
          codec.dispose();
          if (!mounted) {
            frame.image.dispose();
            return;
          }
          final old = images.remove(path);
          if (old != null) {
            imageBytes -= old.width * old.height * 4;
            old.dispose();
          }
          images[path] = frame.image;
          imageBytes += frame.image.width * frame.image.height * 4;
          // Keep a bounded decoded-image cache; source images are never downsampled for zoom.
          for (final key in images.keys.toList()) {
            if (imageBytes <= 64 * 1024 * 1024) break;
            if (pinnedImages.contains(key)) continue;
            final old = images.remove(key)!;
            imageBytes -= old.width * old.height * 4;
            old.dispose();
          }
          camera.invalidate();
        })
        .catchError((Object error) {
          failed.add(path);
        })
        .whenComplete(() {
          pending.remove(path);
          decoding--;
          _drain();
        });
  }

  @override
  void dispose() {
    inertia.dispose();
    camera.dispose();
    for (final i in images.values) {
      i.dispose();
    }
    for (final p in labels.values) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onScaleStart: (_) {
      inertia.stop();
      lastGestureScale = 1;
    },
    onScaleUpdate: (d) {
      final next = (scale * d.scale / lastGestureScale).clamp(.3, 3.0),
          ratio = next / scale;
      offset =
          d.localFocalPoint +
          (offset - (d.localFocalPoint - d.focalPointDelta)) * ratio;
      scale = next;
      lastGestureScale = d.scale;
      pointers = d.pointerCount;
      camera.invalidate();
    },
    onScaleEnd: (d) {
      if (pointers <= 1) {
        velocity = d.velocity.pixelsPerSecond;
        _previousMicros = 0;
        inertia.start();
      }
    },
    onTapUp: (d) {
      final p = (d.localPosition - offset) / scale;
      final col = (p.dx / 184).floor(), row = (p.dy / 236).floor();
      final index = row * 3 + col;
      if (col >= 0 && col < 3 && row >= 0 && index < widget.tracks.length) {
        widget.onSelect(index);
      }
    },
    child: ClipRect(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WallPainter(
            widget.tracks,
            () => offset,
            () => scale,
            images,
            labels,
            request,
            (keys) {
              pinnedImages = keys;
            },
            camera,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _WallPainter extends CustomPainter {
  _WallPainter(
    this.tracks,
    this.offset,
    this.scale,
    this.images,
    this.labels,
    this.request,
    this.pin,
    Listenable repaint,
  ) : super(repaint: repaint);
  final List<AudioTrack> tracks;
  final Offset Function() offset;
  final double Function() scale;
  final Map<String, ui.Image> images;
  final Map<String, TextPainter> labels;
  final void Function(String) request;
  final void Function(Set<String>) pin;
  @override
  void paint(Canvas canvas, Size size) {
    final s = scale(), o = offset();
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.scale(s);
    final first = math.max(0, ((-o.dy / s) / 236).floor() - 1),
        last = math.min(
          (tracks.length / 3).ceil(),
          ((size.height - o.dy) / s / 236).ceil() + 1,
        );
    final visibleImages = <String>{};
    for (var row = first; row < last; row++) {
      for (var col = 0; col < 3; col++) {
        final i = row * 3 + col;
        if (i >= tracks.length) continue;
        final track = tracks[i],
            rect = Rect.fromLTWH(col * 184, row * 236, 176, 224);
        if (rect.right < -o.dx / s || rect.left > (size.width - o.dx) / s) {
          continue;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()..color = const Color(0xffdde8eb),
        );
        final cover = track.coverPath, image = images[cover];
        if (cover != null) visibleImages.add(cover);
        if (cover != null && image == null) request(cover);
        if (image != null) {
          canvas.save();
          canvas.clipRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          );
          paintImage(
            canvas: canvas,
            rect: rect,
            image: image,
            fit: BoxFit.cover,
          );
          canvas.restore();
        }
        final label = labels.putIfAbsent(
          '${track.uri}|${track.title}',
          () => TextPainter(
            text: TextSpan(
              text: track.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xff20363b),
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 2,
            ellipsis: '…',
          )..layout(maxWidth: 160),
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - 64, rect.width, 64),
          Paint()..color = const Color(0xddebf2f3),
        );
        label.paint(canvas, Offset(rect.left + 8, rect.bottom - 56));
      }
    }
    pin(visibleImages);
    while (labels.length > 256) {
      labels.remove(labels.keys.first)!.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WallPainter old) => true;
}

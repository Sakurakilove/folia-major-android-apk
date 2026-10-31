import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:characters/characters.dart';

// Immutable full-DPR glyph and blur masks; no screen/View capture and no per-frame text rasterization.
class GlyphRaster {
  GlyphRaster(
    this.glyph,
    this.nearGlow,
    this.farGlow,
    this.size,
    this.padding,
    this.advance,
    this.offsets,
  );
  final ui.Image glyph, nearGlow, farGlow;
  final ui.Size size;
  final double padding, advance;
  final List<double> offsets;
  int get bytes => glyph.width * glyph.height * 4 * 3;
  void dispose() {
    glyph.dispose();
    nearGlow.dispose();
    farGlow.dispose();
  }
}

class GlyphCache {
  final _ready = <String, GlyphRaster>{};
  final _pending = <String, Future<GlyphRaster?>>{};
  Set<String> _pinned = {};
  int _bytes = 0;
  bool _closed = false;
  Future<void> _tail = Future.value();
  final _failed = <String>{};
  bool isPreparing(String key) =>
      _pending.containsKey(key) || _failed.contains(key);
  static const budget = 64 * 1024 * 1024;
  String key(
    String text,
    double font,
    double dpr,
    bool chorus, [
    double maxWidth = double.infinity,
  ]) => '$text|$font|$dpr|$chorus|$maxWidth';
  GlyphRaster? get(String key) {
    final value = _ready.remove(key);
    if (value != null) _ready[key] = value;
    return value;
  }

  void pin(Set<String> keys) {
    _pinned = keys;
    _trim();
  }

  void _trim() {
    for (final key in _ready.keys.toList()) {
      if (_bytes <= budget) break;
      if (_pinned.contains(key)) continue;
      final old = _ready.remove(key)!;
      _bytes -= old.bytes;
      old.dispose();
    }
  }

  Future<GlyphRaster?> prepare(
    String text,
    double font,
    double dpr,
    bool chorus, [
    double maxWidth = double.infinity,
  ]) {
    final id = key(text, font, dpr, chorus, maxWidth);
    final existing = get(id);
    if (existing != null) return Future.value(existing);
    return _pending.putIfAbsent(id, () {
      final task = _tail.then<GlyphRaster?>((_) async {
        try {
          if (_closed || !_pinned.contains(id)) return null;
          final style = TextStyle(
            fontSize: font,
            fontWeight: FontWeight.w700,
            color: const ui.Color(0xffffffff),
            height: 1.2,
          );
          final paragraph = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: ui.TextDirection.ltr,
          )..layout(maxWidth: maxWidth);
          final r1 = (font * (chorus ? .45 : .28)).roundToDouble();
          final r2 = (font * (chorus ? .9 : .65)).roundToDouble();
          final padding = math.max(r2 * 2 + 4, font / 2);
          final size = ui.Size(
            paragraph.width + 2 * padding,
            paragraph.height + 2 * padding,
          );
          final width = math.max(1, (size.width * dpr).ceil()),
              height = math.max(1, (size.height * dpr).ceil());
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder)..scale(dpr);
          paragraph.paint(canvas, ui.Offset(padding, padding));
          final picture = recorder.endRecording();
          final glyph = await picture.toImage(width, height);
          picture.dispose();
          Future<ui.Image> blur(double radius) async {
            final recorder = ui.PictureRecorder();
            ui.Canvas(recorder).drawImage(
              glyph,
              ui.Offset.zero,
              ui.Paint()
                ..imageFilter = ui.ImageFilter.blur(
                  sigmaX: radius * dpr / 2,
                  sigmaY: radius * dpr / 2,
                ),
            );
            final picture = recorder.endRecording();
            final image = await picture.toImage(width, height);
            picture.dispose();
            return image;
          }

          final nearGlow = await blur(r1), farGlow = await blur(r2);
          final offsets = <double>[0];
          var prefix = '';
          for (final character in text.characters) {
            prefix += character;
            final measure = TextPainter(
              text: TextSpan(text: prefix, style: style),
              textDirection: ui.TextDirection.ltr,
            )..layout();
            offsets.add(measure.width);
            measure.dispose();
          }
          final value = GlyphRaster(
            glyph,
            nearGlow,
            farGlow,
            size,
            padding,
            paragraph.width,
            offsets,
          );
          paragraph.dispose();
          if (_closed) {
            value.dispose();
            return null;
          }
          _ready[id] = value;
          _bytes += value.bytes;
          _trim();
          return value;
        } catch (_) {
          _failed.add(id);
          return null;
        } finally {
          _pending.remove(id);
        }
      });
      _tail = task.then<void>((_) {});
      return task;
    });
  }

  void dispose() {
    _closed = true;
    for (final value in _ready.values) {
      value.dispose();
    }
    _ready.clear();
  }
}

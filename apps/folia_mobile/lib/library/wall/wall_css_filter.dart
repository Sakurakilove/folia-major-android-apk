import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

// Preserve CSS function order and intermediate clamps. Combining saturation and brightness into one matrix changes clipped highlights.
enum WallFilterKind { grayscale, saturate, brightness }

class WallFilterOp {
  const WallFilterOp(this.kind, this.amount);
  final WallFilterKind kind;
  final double amount;
  double get identity => kind == WallFilterKind.grayscale ? 0 : 1;
  ui.ColorFilter get native {
    if (kind == WallFilterKind.brightness) {
      return ui.ColorFilter.matrix([
        amount,
        0,
        0,
        0,
        0,
        0,
        amount,
        0,
        0,
        0,
        0,
        0,
        amount,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    // Chromium 154 cc/paint/render_surface_filters.cc: grayscale and saturate intentionally use different luma coefficients.
    final gray = kind == WallFilterKind.grayscale,
        p = gray ? 1 - amount : amount,
        r = gray ? .2126 : .213,
        g = gray ? .7152 : .715,
        m0 = r + (1 - r) * p,
        m1 = g - g * p,
        m5 = r - r * p,
        m6 = g + (1 - g) * p,
        m10 = r - r * p,
        m11 = g - g * p;
    return ui.ColorFilter.matrix([
      m0,
      m1,
      1 - (m0 + m1),
      0,
      0,
      m5,
      m6,
      1 - (m5 + m6),
      0,
      0,
      m10,
      m11,
      1 - (m10 + m11),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is WallFilterOp && kind == other.kind && amount == other.amount;
  @override
  int get hashCode => Object.hash(kind, amount);
}

class WallCssFilter {
  const WallCssFilter(this.operations);
  static const none = WallCssFilter([]);
  final List<WallFilterOp> operations;
  bool compatible(WallCssFilter other) =>
      operations.isEmpty ||
      other.operations.isEmpty ||
      (operations.length == other.operations.length &&
          List.generate(
            operations.length,
            (i) => i,
          ).every((i) => operations[i].kind == other.operations[i].kind));
  static WallCssFilter interpolate(WallCssFilter a, WallCssFilter b, double p) {
    assert(a.compatible(b));
    final shape = a.operations.isEmpty ? b.operations : a.operations;
    return WallCssFilter(
      List.generate(shape.length, (i) {
        final from = a.operations.isEmpty
                ? shape[i].identity
                : a.operations[i].amount,
            to = b.operations.isEmpty
                ? shape[i].identity
                : b.operations[i].amount;
        return WallFilterOp(shape[i].kind, from + (to - from) * p);
      }),
    );
  }

  ui.ImageFilter? get native {
    ui.ImageFilter? result;
    for (final op in operations) {
      if (op.amount == op.identity) continue;
      final next = op.native;
      result = result == null
          ? next
          : ui.ImageFilter.compose(outer: next, inner: result);
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is WallCssFilter && listEquals(operations, other.operations);
  @override
  int get hashCode => Object.hashAll(operations);
}

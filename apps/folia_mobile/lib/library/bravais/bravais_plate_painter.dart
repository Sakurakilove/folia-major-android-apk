import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_drawing/path_drawing.dart';

import '../wall/wall_types.dart';
import 'bravais_plate_geometry.dart';

// Native paths are retained per mounted block and rebuilt only when its actual holes change, using the same reflow snapshot as the posters.
class BravaisPlatePainter extends ChangeNotifier {
  BravaisPlatePainter({
    required Color color,
    List<BravaisPlateBlock> left = const [],
    List<BravaisPlateBlock> right = const [],
  }) : _left = List.unmodifiable(left),
       _right = List.unmodifiable(right),
       _paint = Paint()..color = color;
  List<BravaisPlateBlock> _left, _right;
  final Paint _paint;
  bool _dirty = true;
  Map<String, WallRect>? _prepared;
  final _paths = <String, ({String d, Path path})>{};
  void update(
    List<BravaisPlateBlock> left,
    List<BravaisPlateBlock> right,
    Color color,
  ) {
    _left = List.unmodifiable(left);
    _right = List.unmodifiable(right);
    _paint.color = color;
    _dirty = true;
    final keys = {
      for (final b in [...left, ...right]) b.key,
    };
    _paths.removeWhere((key, _) => !keys.contains(key));
    notifyListeners();
  }

  void _prepare(Map<String, WallRect> reflow) {
    if (!_dirty && identical(reflow, _prepared)) return;
    _dirty = false;
    _prepared = reflow;
    for (final block in [..._left, ..._right]) {
      final d = buildBravaisPlatePath(block.frame, [
        for (final h in block.holes.entries) reflow[h.key] ?? h.value,
      ]);
      final cached = _paths[block.key];
      if (cached == null || cached.d != d) {
        _paths[block.key] = (
          d: d,
          path: parseSvgPathData(d)..fillType = PathFillType.evenOdd,
        );
      }
    }
  }

  void paint(Canvas canvas, bool left, Map<String, WallRect> reflow) {
    _prepare(reflow);
    for (final block in left ? _left : _right) {
      final cached = _paths[block.key]!;
      canvas.save();
      canvas.translate(
        roundPlateCoordinate(block.frame.x),
        roundPlateCoordinate(block.frame.y),
      );
      canvas.drawPath(cached.path, _paint);
      canvas.restore();
    }
  }

  @override
  void dispose() {
    _prepared = null;
    _paths.clear();
    super.dispose();
  }
}

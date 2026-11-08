import 'dart:convert';

import '../../wall/wall_slots.dart';
import '../../wall/wall_types.dart';
import '../bravais_frame.dart';
import '../shape/bravais_wall_shape.dart';
import '../shape/bravais_shape_collect.dart';

// Session storage remains app-owned and synchronous. Read it afresh on each restore so layout.forget cannot leave a stale in-memory record; never write during a paint or pointer frame.
const bravaisLayoutStoragePrefix = 'folia_bravais_layout:v1:';

class BravaisLayoutRecord {
  const BravaisLayoutRecord({
    this.center,
    this.anchorX,
    this.startSlotKey,
    this.focusSlotKey,
    this.shapeKind,
  });
  final WallPoint? center;
  final double? anchorX;
  final String? startSlotKey, focusSlotKey, shapeKind;
  Map<String, Object?> toJson() => {
    'center': center == null
        ? null
        : {'x': _jsonNumber(center!.x), 'y': _jsonNumber(center!.y)},
    'anchorX': _jsonNumber(anchorX),
    'startSlotKey': startSlotKey,
    'focusSlotKey': focusSlotKey,
    if (shapeKind != null) 'shapeKind': shapeKind,
  };
}

double? _jsonNumber(num? value) =>
    value?.isFinite == true ? value!.toDouble() : null;
String? _nonempty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
BravaisLayoutRecord? parseBravaisLayoutRecord(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map && decoded is! List) return null;
    final value = decoded is Map ? decoded : const <String, Object?>{},
        c = value['center'];
    final x = c is Map && c['x'] is num ? _jsonNumber(c['x'] as num) : null,
        y = c is Map && c['y'] is num ? _jsonNumber(c['y'] as num) : null;
    return BravaisLayoutRecord(
      center: x != null && y != null ? WallPoint(x, y) : null,
      anchorX: value['anchorX'] is num
          ? _jsonNumber(value['anchorX'] as num)
          : null,
      startSlotKey: _nonempty(value['startSlotKey']),
      focusSlotKey: _nonempty(value['focusSlotKey']),
      shapeKind: value['shapeKind'] == 'explore' ? 'explore' : null,
    );
  } catch (_) {
    return null;
  }
}

BravaisLayoutRecord fitBravaisLayoutToShape(
  BravaisLayoutRecord record,
  BravaisWallShape shape,
) {
  final anchor = record.anchorX == null
          ? null
          : nearestShapeBoundaryX(shape, record.anchorX!),
      kind = record.shapeKind ?? 'blocks',
      nextKind = shape.explore ? 'explore' : 'blocks';
  if (kind == nextKind) {
    return BravaisLayoutRecord(
      center: record.center,
      anchorX: anchor,
      startSlotKey: record.startSlotKey,
      focusSlotKey: record.focusSlotKey,
      shapeKind: kind,
    );
  }
  final block = bravaisBlockShape.blockSize,
      size = kind == 'explore'
          ? (
              width: block.width + bravaisMetrics.cellSize / 2,
              height: block.height + bravaisMetrics.cellSize / 2,
            )
          : block,
      address = record.startSlotKey == null
          ? null
          : parseWallSlotKey(record.startSlotKey!);
  return BravaisLayoutRecord(
    center: record.center,
    anchorX: anchor,
    startSlotKey: address == null
        ? null
        : shape.startKeyAt(
            WallPoint(
              (address.column + .5) * size.width,
              (address.row + .5) * size.height,
            ),
          ),
    focusSlotKey: null,
    shapeKind: nextKind,
  );
}

class BravaisLayoutMemory {
  const BravaisLayoutMemory({required this.getItem, required this.setItem});
  final String? Function(String key)? getItem;
  final void Function(String key, String value)? setItem;
  BravaisLayoutRecord? read(String sessionKey) => parseBravaisLayoutRecord(
    getItem?.call(bravaisLayoutStoragePrefix + sessionKey),
  );
  void write(String sessionKey, BravaisLayoutRecord record) {
    try {
      setItem?.call(
        bravaisLayoutStoragePrefix + sessionKey,
        jsonEncode(record.toJson()),
      );
    } catch (_) {
      /* Source layout memory is optional if storage is unavailable/full. */
    }
  }
}

import 'block_templates.dart';
import 'wall_types.dart';
import '../../rendering/js_number.dart';

// A home wall seat is a world identity, independent of content/filter/reflow; only its rectangle changes on expansion.
class WallSlot {
  const WallSlot(
    this.column,
    this.row,
    this.slotIndex,
    this.x,
    this.y,
    this.width,
    this.height,
    this.area,
  );
  factory WallSlot.fromBlock(
    int column,
    int row,
    int index,
    WallBlockSlot rect,
    WallMetrics metrics,
  ) {
    final pitch = metrics.pitch;
    return WallSlot(
      column,
      row,
      index,
      column * wallBlockCols * pitch + rect.x * pitch,
      row * wallBlockRows * pitch + rect.y * pitch,
      rect.cols * pitch - metrics.gap,
      rect.rows * pitch - metrics.gap,
      rect.cols * rect.rows,
    );
  }
  final int column, row, slotIndex, area;
  final double x, y, width, height;
  String get key => '$column,$row,$slotIndex';
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
  WallBounds get bounds => WallBounds(x, x + width, y, y + height);
  Map<String, Object> toJson() => {
    'key': key,
    'column': column,
    'row': row,
    'slotIndex': slotIndex,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'centerX': centerX,
    'centerY': centerY,
    'area': area,
  };
}

({double width, double height}) wallBlockSize(WallMetrics metrics) => (
  width: wallBlockCols * metrics.pitch,
  height: wallBlockRows * metrics.pitch,
);
List<WallSlot> blockSlots(int column, int row, WallMetrics metrics) {
  final template = blockTemplate(column, row);
  return [
    for (var i = 0; i < template.length; i++)
      WallSlot.fromBlock(column, row, i, template[i], metrics),
  ];
}

WallSlot? wallSlot(int column, int row, int slotIndex, WallMetrics metrics) =>
    slotIndex < 0 || slotIndex >= wallSlotsPerBlock
    ? null
    : WallSlot.fromBlock(
        column,
        row,
        slotIndex,
        blockTemplate(column, row)[slotIndex],
        metrics,
      );

({int column, int row, int slotIndex})? parseWallSlotKey(String key) {
  final parts = key.split(',');
  if (parts.length != 3) return null;
  // Source Number() also accepts radix prefixes and precisely ECMAScript whitespace.
  final values = parts.map(jsNumberFromString).toList(growable: false);
  if (values.any((v) => !v.isFinite || v != v.truncateToDouble())) {
    return null;
  }
  return (
    column: values[0].toInt(),
    row: values[1].toInt(),
    slotIndex: values[2].toInt(),
  );
}

List<WallSlot> collectBlockRangeSlots(
  WallBlockRange columns,
  WallBlockRange rows,
  WallMetrics metrics,
) => [
  for (var row = rows.from; row < rows.to; row++)
    for (var column = columns.from; column < columns.to; column++)
      ...blockSlots(column, row, metrics),
];
List<WallSlot> collectWallSlots(
  WallBounds bounds,
  WallMetrics metrics, {
  int? limit,
}) {
  final block = wallBlockSize(metrics), result = <WallSlot>[];
  for (
    var row = (bounds.top / block.height).floor();
    row <= (bounds.bottom / block.height).floor();
    row++
  ) {
    for (
      var column = (bounds.left / block.width).floor();
      column <= (bounds.right / block.width).floor();
      column++
    ) {
      for (final slot in blockSlots(column, row, metrics)) {
        if (!slot.bounds.overlaps(bounds)) continue;
        result.add(slot);
        if (limit != null && result.length >= limit) return result;
      }
    }
  }
  return result;
}

List<WallSlot>? layoutFocusedBlock(
  int column,
  int row,
  int focusedSlot,
  WallMetrics metrics,
) {
  final reflow = blockReflow(column, row, focusedSlot);
  return reflow == null
      ? null
      : [
          for (var i = 0; i < reflow.length; i++)
            WallSlot.fromBlock(column, row, i, reflow[i], metrics),
        ];
}

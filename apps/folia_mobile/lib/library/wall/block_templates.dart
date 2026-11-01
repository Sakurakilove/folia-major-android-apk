import 'block_templates_data.dart';
import 'wall_types.dart';

// Preserve the original absolute block hash, reflection and stable slot indices, including negative coordinates.
const wallBlockCols = 12, wallBlockRows = 8, wallSlotsPerBlock = 12;
const wallExpansionSpan = (cols: 6, rows: 6);
int wallBlockOrientation(int column, int row) {
  var value = ((column * 0x9e3779b1) ^ (row * 0x85ebca6b)) & 0xffffffff;
  value = ((value ^ (value >>> 15)) * 0x2c1b3c6d) & 0xffffffff;
  value = (value ^ (value >>> 12)) & 0xffffffff;
  return ((column + row * 2) % 4) * 4 + value % 4;
}

List<WallBlockSlot> blockTemplate(int column, int row) =>
    wallBlockTemplates[wallBlockOrientation(column, row)];
List<WallBlockSlot>? blockReflow(int column, int row, int expandedSlot) =>
    expandedSlot < 0 || expandedSlot >= wallSlotsPerBlock
    ? null
    : wallBlockReflows[wallBlockOrientation(column, row)][expandedSlot];

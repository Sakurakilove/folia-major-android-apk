import '../lyrics/lyric_types.dart';
import '../lyrics/semantic_layout.dart';
import '../visualizer/glow_word/glow_word_variants.dart';

// Typed source column/chunk/word contracts; chunkUnits retain the original parser/segmentation metadata.
class PartitaWordConfig implements GlowWordGeometry {
  const PartitaWordConfig(
    this.id,
    this.x,
    this.y,
    this.rotate,
    this.scale,
    this.marginBottom,
    this.alignSelf,
    this.passedRotate,
  );
  final String id, marginBottom, alignSelf;
  @override
  final double x;
  @override
  final double y;
  @override
  final double rotate;
  @override
  final double scale;
  @override
  final double passedRotate;
  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'rotate': rotate,
    'scale': scale,
    'marginBottom': marginBottom,
    'alignSelf': alignSelf,
    'passedRotate': passedRotate,
  };
}

class PartitaChunkLayout {
  const PartitaChunkLayout(
    this.units,
    this.words,
    this.displayWords,
    this.config,
    this.order,
    this.rowIndex,
  );
  final List<LyricLayoutUnit> units;
  final List<LyricWord> words, displayWords;
  final PartitaWordConfig config;
  final int order, rowIndex;
  Map<String, dynamic> toJson() => {
    'chunkUnits': units.map((u) => u.toJson()).toList(),
    'chunkWords': words.map((w) => w.toJson()).toList(),
    'displayWords': displayWords.map((w) => w.toJson()).toList(),
    'config': config.toJson(),
    'order': order,
    'rowIndex': rowIndex,
  };
}

class PartitaColumn {
  const PartitaColumn(this.id, this.chunks);
  final String id;
  final List<PartitaChunkLayout> chunks;
  Map<String, dynamic> toJson() => {
    'id': id,
    'words': chunks.map((c) => c.toJson()).toList(),
  };
}

class PartitaLayout {
  const PartitaLayout(
    this.columns,
    this.totalGraphemes,
    this.perspective, {
    this.columnGap = '2rem',
  });
  static const empty = PartitaLayout([], 0, 1000, columnGap: '1.6rem');
  final List<PartitaColumn> columns;
  final int totalGraphemes;
  final double perspective;
  final String columnGap;
  Map<String, dynamic> toJson() => {
    'columns': columns.map((c) => c.toJson()).toList(),
    'totalGraphemes': totalGraphemes,
    'lineConfig': {
      'perspective': perspective,
      'alignItems': 'items-center',
      'justifyContent': 'justify-center',
      'columnGap': columnGap,
    },
  };
}

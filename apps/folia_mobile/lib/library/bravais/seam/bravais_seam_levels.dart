import 'package:flutter/foundation.dart';

import 'bravais_seam_level.dart';

// App-owned level service broadcasts only discrete changes; first viewport measurement preserves the original initial level.
class BravaisSeamLevels extends ValueNotifier<BravaisSeamLevelState> {
  BravaisSeamLevels(double initialWidth)
    : super(
        BravaisSeamLevelState(
          defaultSeamLevel(initialWidth),
          defaultSeamLevel(initialWidth),
        ),
      );
  double viewportWidth = 0;
  void setLevel(BravaisSeamLevel level) => value = value.apply(level);
  void restore() => value = value.restore();
  void syncViewport(double width) {
    if (viewportWidth == width) return;
    final previous = viewportWidth;
    viewportWidth = width;
    if (previous != 0) value = value.resize(previous, width);
  }
}

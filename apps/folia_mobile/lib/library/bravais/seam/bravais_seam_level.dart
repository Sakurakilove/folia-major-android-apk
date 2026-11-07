import '../display/bravais_wall_data.dart';

// This state belongs to the app's Bravais stage service, not an individual layer; folding and the remembered restore level survive navigation/unmounts.
enum BravaisSeamLevel { full, spine, hidden }

enum BravaisSeamVariant {
  home('home'),
  homeSpine('home-spine'),
  full('full'),
  spine('spine'),
  none('none'),
  panel('panel'),
  form('form'),
  search('search'),
  poster('poster');

  const BravaisSeamVariant(this.wireName);
  final String wireName;
}

bool isNarrowBravaisViewport(double width) => width < 900;
BravaisSeamLevel defaultSeamLevel(double width) =>
    isNarrowBravaisViewport(width)
    ? BravaisSeamLevel.spine
    : BravaisSeamLevel.full;

class BravaisSeamLevelState {
  const BravaisSeamLevelState(this.level, this.restoreLevel)
    : assert(restoreLevel != BravaisSeamLevel.hidden);
  final BravaisSeamLevel level, restoreLevel;
  BravaisSeamLevelState apply(BravaisSeamLevel next) {
    if (next == level) return this;
    return next == BravaisSeamLevel.hidden
        ? BravaisSeamLevelState(
            next,
            level == BravaisSeamLevel.hidden ? restoreLevel : level,
          )
        : BravaisSeamLevelState(next, next);
  }

  BravaisSeamLevelState restore() =>
      level == BravaisSeamLevel.hidden ? apply(restoreLevel) : this;
  BravaisSeamLevelState resize(double previous, double next) {
    if (isNarrowBravaisViewport(previous) == isNarrowBravaisViewport(next)) {
      return this;
    }
    final fallback = defaultSeamLevel(next);
    return level == BravaisSeamLevel.hidden
        ? BravaisSeamLevelState(BravaisSeamLevel.hidden, fallback)
        : BravaisSeamLevelState(fallback, fallback);
  }
}

double seamOpenWidth(BravaisLayerSurface surface, BravaisSeamLevel level) =>
    switch (level) {
      BravaisSeamLevel.hidden => 0,
      BravaisSeamLevel.spine => 64,
      BravaisSeamLevel.full => surface == BravaisLayerSurface.home ? 120 : 300,
    };
BravaisSeamVariant seamVariant(
  BravaisLayerSurface surface,
  BravaisSeamLevel level,
) => level == BravaisSeamLevel.hidden
    ? BravaisSeamVariant.none
    : surface == BravaisLayerSurface.home
    ? (level == BravaisSeamLevel.spine
          ? BravaisSeamVariant.homeSpine
          : BravaisSeamVariant.home)
    : (level == BravaisSeamLevel.spine
          ? BravaisSeamVariant.spine
          : BravaisSeamVariant.full);
double seamVariantWidth(BravaisSeamVariant variant) => switch (variant) {
  BravaisSeamVariant.home => 120,
  BravaisSeamVariant.full => 300,
  BravaisSeamVariant.homeSpine || BravaisSeamVariant.spine => 64,
  _ => 0,
};

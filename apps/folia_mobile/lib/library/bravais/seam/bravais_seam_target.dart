import '../display/bravais_wall_data.dart';
import 'bravais_seam_level.dart';

// Preserve the original form/panel/search/filter/poster/level precedence; temporary openings never rewrite the user's stored level.
double bravaisPanelWidth(double width) => (width - 52).clamp(160.0, 420.0);
double bravaisPosterWidth(double width) =>
    (width * .46).clamp(520.0, 680.0).roundToDouble();

class BravaisSeamTargetInput {
  const BravaisSeamTargetInput({
    required this.surface,
    required this.level,
    required this.viewportWidth,
    this.formOpen = false,
    this.panelOpen = false,
    this.filterOpen = false,
    this.searchOpen = false,
    this.poster = false,
  });
  final BravaisLayerSurface surface;
  final BravaisSeamLevel level;
  final double viewportWidth;
  final bool formOpen, panelOpen, filterOpen, searchOpen, poster;
  BravaisSeamLevel get effectiveLevel =>
      formOpen || filterOpen || (panelOpen && level != BravaisSeamLevel.hidden)
      ? BravaisSeamLevel.full
      : level;
}

class BravaisSeamTarget {
  const BravaisSeamTarget(this.width, this.variant);
  final double width;
  final BravaisSeamVariant variant;
  static BravaisSeamTarget resolve(BravaisSeamTargetInput input) {
    final surface = input.surface,
        level = input.level,
        width = input.viewportWidth;
    if (surface != BravaisLayerSurface.home && input.formOpen) {
      return const BravaisSeamTarget(300, BravaisSeamVariant.form);
    }
    if (input.panelOpen && level != BravaisSeamLevel.hidden) {
      return BravaisSeamTarget(
        bravaisPanelWidth(width),
        BravaisSeamVariant.panel,
      );
    }
    if (surface == BravaisLayerSurface.home &&
        input.searchOpen &&
        level != BravaisSeamLevel.hidden) {
      return const BravaisSeamTarget(300, BravaisSeamVariant.search);
    }
    if (input.poster && level == BravaisSeamLevel.full && !input.filterOpen) {
      return BravaisSeamTarget(
        bravaisPosterWidth(width),
        BravaisSeamVariant.poster,
      );
    }
    return BravaisSeamTarget(
      seamOpenWidth(surface, input.effectiveLevel),
      seamVariant(surface, input.effectiveLevel),
    );
  }
}

double resolveSeamVariantWidth(
  BravaisSeamVariant variant,
  double viewportWidth,
) => switch (variant) {
  BravaisSeamVariant.form || BravaisSeamVariant.search => 300,
  BravaisSeamVariant.panel => bravaisPanelWidth(viewportWidth),
  BravaisSeamVariant.poster => bravaisPosterWidth(viewportWidth),
  _ => seamVariantWidth(variant),
};

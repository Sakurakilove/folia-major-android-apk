import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import '../../wall/wall_paint_boundary.dart';
import '../bravais_frame.dart';
import 'bravais_seam_bottom_padding.dart';
import 'bravais_seam_content_motion.dart';
import 'bravais_seam_flight.dart';
import 'bravais_seam_level.dart';
import 'bravais_seam_motion_layer.dart';
import 'bravais_seam_target.dart';
import 'bravais_seam_viewport.dart';

// Assemble the actual retained seam; only the original rendered identity/data changes build its body. Full variant content, navigation and material providers stay explicit, never replaced by a new product shell.
class BravaisSeamScene<T> extends StatelessWidget {
  const BravaisSeamScene({
    super.key,
    required this.motion,
    required this.frame,
    required this.viewportWidth,
    required this.bottom,
    required this.surfaceFor,
    required this.contentBuilder,
    this.axis = BravaisSeamFlipAxis.y,
  });
  final BravaisSeamContentMotion<T> motion;
  final ValueListenable<BravaisFrame> frame;
  final double viewportWidth;
  final ValueListenable<double> bottom;
  final CustomPainter Function(BravaisRenderedSeam<T> rendered) surfaceFor;
  final Widget Function(BuildContext context, BravaisRenderedSeam<T> rendered)
  contentBuilder;
  final BravaisSeamFlipAxis axis;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: motion.content,
    builder: (context, rendered, _) => BravaisSeamViewport(
      frame: frame,
      contentWidth: resolveSeamVariantWidth(rendered.variant, viewportWidth),
      surface: surfaceFor(rendered),
      poster: rendered.variant == BravaisSeamVariant.poster,
      child: BravaisSeamMotionLayer(
        motion: motion,
        axis: axis,
        child: BravaisSeamBottomPadding(
          bottom: bottom,
          child: WallPaintBoundary(child: contentBuilder(context, rendered)),
        ),
      ),
    ),
  );
}

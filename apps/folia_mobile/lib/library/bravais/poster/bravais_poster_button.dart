import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../../../rendering/css_text.dart';
import '../../../rendering/folia_icons.dart';
import '../../wall/wall_css_paint.dart';
import '../../wall/wall_typography.dart';
import '../tiles/bravais_control.dart';

part 'bravais_poster_button_surface.dart';

// Actual shared poster CTA, retaining artist/album selectors. All labels/actions come from the original caller; absent actions must be omitted by that caller rather than inventing disabled product controls.
class BravaisPosterButtonPalette {
  const BravaisPosterButtonPalette({
    this.paper = const Color(0xffefe9dc),
    this.ink = const Color(0xff141210),
    this.accent = const Color(0xffe4462b),
    this.artistInk = const Color(0xfff6f6f6),
    this.edge = const Color(0xff3a3a3d),
  });
  final Color paper, ink, accent, artistInk, edge;
}

class BravaisPosterButtonStyle {
  BravaisPosterButtonStyle({
    required this.palette,
    required this.album,
    required this.primary,
    required bool hovered,
  }) {
    borderWidth = album ? 2 : 1; // Blink snaps this CSS 1.5px border to 1 layout px, independently of device DPR.
    border = album
        ? palette.ink
        : Color.from(alpha: primary ? 1 : .85, red: 1, green: 1, blue: 1);
    background = album
        ? primary
              ? palette.accent
              : hovered
              ? wallSrgbMix(palette.paper, palette.ink, .14)
              : palette.paper
        : primary
        ? const Color(0xffffffff)
        : hovered
        ? const Color.from(alpha: .16, red: 1, green: 1, blue: 1)
        : const Color.from(
            alpha: .3,
            red: 20 / 255,
            green: 20 / 255,
            blue: 22 / 255,
          );
    ink = album
        ? primary
              ? palette.paper
              : palette.ink
        : primary
        ? const Color(0xff2a2a2c)
        : palette.artistInk;
    shadow = album
        ? palette.ink
        : primary
        ? palette.edge
        : const Color(0x00000000);
  }
  final BravaisPosterButtonPalette palette;
  final bool album, primary;
  late final Color background, border, ink, shadow;
  late final double borderWidth;
  int get weight => primary ? 900 : 800;
}

class BravaisPosterButton extends StatelessWidget {
  const BravaisPosterButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.typography,
    this.palette = const BravaisPosterButtonPalette(),
    this.album = false,
    this.primary = false,
  });
  final String label;
  final FoliaIconData icon;
  final VoidCallback onPressed;
  final WallTypography typography;
  final BravaisPosterButtonPalette palette;
  final bool album, primary;
  @override
  Widget build(BuildContext context) => BravaisControl(
    label: label,
    onPressed: onPressed,
    builder: (context, hovered, focused) {
      final style = BravaisPosterButtonStyle(
        palette: palette,
        album: album,
        primary: primary,
        hovered: hovered,
      );
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: _PosterButtonSurface(
          style: style,
          focused: focused,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20 + style.borderWidth,
              vertical: style.borderWidth,
            ),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FoliaPreparedIcon(icon, color: style.ink, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      cssNormalText(label),
                      style: typography.style(
                        15,
                        color: style.ink,
                        weight: style.weight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PosterButtonSurface extends SingleChildRenderObjectWidget {
  const _PosterButtonSurface({
    required this.style,
    required this.focused,
    super.child,
  });
  final BravaisPosterButtonStyle style;
  final bool focused;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBravaisPosterButton(style, focused);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderBravaisPosterButton renderObject,
  ) => renderObject.update(style, focused);
}

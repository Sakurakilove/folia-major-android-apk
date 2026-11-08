import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../rendering/css_numeric.dart';
import 'bravais_album_entrance.dart';
import 'bravais_album_entrance_layer.dart';
import 'bravais_album_motion.dart';

part 'bravais_album_layout_box.dart';

// Actual original UI flex skeleton; ground remains outside the safe-area transform. Callers supply the full original bar/title/facts/actions and vertical script renderer, never placeholder product UI.
class BravaisAlbumLayout extends StatelessWidget {
  const BravaisAlbumLayout({
    super.key,
    required this.entrance,
    required this.top,
    required this.title,
    required this.cover,
    required this.scrap,
    required this.bottom,
  });
  final BravaisAlbumEntrance entrance;
  final Widget top, title, scrap;
  final Widget Function(Size posterSize) cover;
  final List<Widget> bottom;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _AlbumLayoutLeaf(
      children: [
        BravaisAlbumEntranceLayer(
          motion: entrance.signal(BravaisAlbumPart.top),
          child: top,
        ),
        cover(constraints.biggest),
        BravaisAlbumEntranceLayer(
          motion: entrance.signal(BravaisAlbumPart.scrap),
          child: ClipRect(child: scrap),
        ),
        title,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < bottom.length; i++) ...[
              if (i != 0) const SizedBox(height: 12),
              BravaisAlbumEntranceLayer(
                motion: entrance.signal(BravaisAlbumPart.bottom, i),
                child: bottom[i],
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _AlbumLayoutLeaf extends MultiChildRenderObjectWidget {
  const _AlbumLayoutLeaf({required super.children});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBravaisAlbumLayout();
}

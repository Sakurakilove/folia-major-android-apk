part of 'explore_layout.dart';

// The same combined 400-instance budget and heading-first traversal as the source, including strict edge overlap and negative world coordinates.
extension ExploreLayoutCollect on ExploreLayout {
  ({List<WallQueueInstance> posters, List<ExploreHeading> headings}) near(
    WallBounds bounds,
    double overscan,
  ) {
    final posters = <WallQueueInstance>[], headings = <ExploreHeading>[];
    if (lots.isEmpty) return (posters: posters, headings: headings);
    final view = WallBounds(
      bounds.left - overscan,
      bounds.right + overscan,
      bounds.top - overscan,
      bounds.bottom + overscan,
    );
    for (
      var row = (view.top / pitchY).floor();
      row <= (view.bottom / pitchY).floor();
      row++
    ) {
      for (
        var col = (view.left / pitchX).floor();
        col <= (view.right / pitchX).floor();
        col++
      ) {
        final lot = lotAt(col, row), heading = rectOf(lot.heading, col, row);
        if (heading.bounds.overlaps(view)) {
          headings.add(
            ExploreHeading(
              'heading:$col:$row',
              lot.section,
              lot.part,
              lot.parts,
              heading.x,
              heading.y,
              heading.width,
              heading.height,
            ),
          );
          if (posters.length + headings.length >= 400) {
            return (posters: posters, headings: headings);
          }
        }
        for (var seat = 0; seat < lot.seats.length; seat++) {
          final poster = posterAt(col, row, seat);
          if (!poster.bounds.overlaps(view)) continue;
          posters.add(poster);
          if (posters.length + headings.length >= 400) {
            return (posters: posters, headings: headings);
          }
        }
      }
    }
    return (posters: posters, headings: headings);
  }
}

// Original wall coordinates stay in world units; camera translation is logical screen px and rendering uses the full device DPR.
class WallPoint {
  const WallPoint(this.x, this.y);
  final double x, y;
  Map<String, double> toJson() => {'x': x, 'y': y};
}

class WallBounds {
  const WallBounds(this.left, this.right, this.top, this.bottom);
  final double left, right, top, bottom;
  bool overlaps(WallBounds other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;
  Map<String, double> toJson() => {
    'left': left,
    'right': right,
    'top': top,
    'bottom': bottom,
  };
}

class WallMetrics {
  const WallMetrics(this.cellSize, this.gap);
  final double cellSize, gap;
  double get pitch => cellSize + gap;
  Map<String, double> toJson() => {'cellSize': cellSize, 'gap': gap};
}

class WallCamera {
  const WallCamera(this.x, this.y, this.scale);
  final double x, y, scale;
  Map<String, double> toJson() => {'x': x, 'y': y, 'scale': scale};
}

class WallView {
  // Public lineX remains optional so resizing an implicit centre keeps tracking width / 2.
  const WallView(this.width, this.height, this.scale, {double? lineX})
    // ignore: prefer_initializing_formals
    : _lineX = lineX;
  final double width, height, scale;
  final double? _lineX;
  double get lineX => _lineX ?? width / 2;
  WallView withScale(double value) =>
      WallView(width, height, value, lineX: _lineX);
  Map<String, double> toJson() => {
    'width': width,
    'height': height,
    'scale': scale,
    if (_lineX != null) 'lineX': _lineX,
  };
}

class WallBlockSlot {
  const WallBlockSlot(this.x, this.y, this.cols, this.rows);
  final int x, y, cols, rows;
  Map<String, int> toJson() => {'x': x, 'y': y, 'cols': cols, 'rows': rows};
}

class WallRect {
  const WallRect(this.x, this.y, this.width, this.height);
  final double x, y, width, height;
  bool same(WallRect other) =>
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height;
  WallRect mix(WallRect to, double progress) => WallRect(
    x + (to.x - x) * progress,
    y + (to.y - y) * progress,
    width + (to.width - width) * progress,
    height + (to.height - height) * progress,
  );
  WallBounds get bounds => WallBounds(x, x + width, y, y + height);
  Map<String, double> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class WallBlockRange {
  const WallBlockRange(this.from, this.to);
  final int from, to;
  int get length => to - from;
  Map<String, int> toJson() => {'from': from, 'to': to};
}

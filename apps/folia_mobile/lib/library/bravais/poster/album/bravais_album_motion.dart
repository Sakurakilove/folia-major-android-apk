import '../../../../visualizer/motion/chromium_css_bezier.dart';
import '../../../../rendering/css_numeric.dart';

// CSS animation-timing-function applies between each property's keyframes. It is not WAAPI's effect-wide easing, and unspecified properties do not acquire the opacity's 60%/70% stops.
enum BravaisAlbumPart {
  root,
  paper,
  hatch,
  dots,
  ghost,
  cover,
  tape,
  scrap,
  kicker,
  word,
  titleShadow,
  underline,
  bottom,
  top,
}

enum BravaisAlbumCoverState { ordinary, pending, landed }

typedef BravaisAlbumMotion = ({
  double opacity,
  double x,
  double y,
  double rotate,
  double scaleX,
  double scaleY,
  double progress,
  bool visible,
});
const bravaisAlbumRest = (
  opacity: 1.0,
  x: 0.0,
  y: 0.0,
  rotate: 0.0,
  scaleX: 1.0,
  scaleY: 1.0,
  progress: 1.0,
  visible: true,
);
typedef _Curve = ({double x1, double y1, double x2, double y2});
const _out = (x1: 0.0, y1: 0.0, x2: .58, y2: 1.0),
    _rise = (x1: .2, y1: .8, x2: .3, y2: 1.0),
    _cover = (x1: .2, y1: .9, x2: .3, y2: 1.08),
    _word = (x1: .2, y1: .9, x2: .3, y2: 1.1),
    _tape = (x1: .3, y1: .7, x2: .3, y2: 1.2);
final _curves = <_Curve, ChromiumCssBezier>{};
double _ease(_Curve curve, double value) => _curves
    .putIfAbsent(
      curve,
      () => ChromiumCssBezier(curve.x1, curve.y1, curve.x2, curve.y2),
    )
    .sampleUnit(value.clamp(0.0, 1.0));
double _phase(double elapsed, double delay, double duration) =>
    ((elapsed - delay) / duration).clamp(0.0, 1.0);
double _opacity(double value) => value.clamp(0.0, 1.0);
BravaisAlbumMotion _frame({
  double opacity = 1,
  double x = 0,
  double y = 0,
  double rotate = 0,
  double scaleX = 1,
  double scaleY = 1,
  double progress = 1,
  bool visible = true,
  bool em = false,
}) => (
  opacity: cssFloat32(_opacity(opacity)),
  x: em ? x : cssFloat32(x),
  y: em ? y : cssFloat32(y),
  rotate: rotate,
  scaleX: scaleX,
  scaleY: scaleY,
  progress: progress,
  visible: visible,
);

BravaisAlbumMotion sampleBravaisAlbumMotion({
  required BravaisAlbumPart part,
  required double elapsed,
  bool reducedMotion = false,
  BravaisAlbumCoverState cover = BravaisAlbumCoverState.ordinary,
  int index = 0,
  bool space = false,
}) {
  if (part == BravaisAlbumPart.root) {
    return reducedMotion
        ? _frame(opacity: _ease(_out, _phase(elapsed, 0, 180)))
        : bravaisAlbumRest;
  }
  if (part == BravaisAlbumPart.cover &&
      cover != BravaisAlbumCoverState.ordinary) {
    return _frame(visible: cover != BravaisAlbumCoverState.pending);
  }
  if (reducedMotion || part == BravaisAlbumPart.word && space) {
    return part == BravaisAlbumPart.scrap
        ? _frame(opacity: .85)
        : bravaisAlbumRest;
  }
  double phase(double delay, double duration, _Curve curve) =>
      _ease(curve, _phase(elapsed, delay, duration));
  switch (part) {
    case BravaisAlbumPart.paper:
      return _frame(
        progress: phase(0, 620, (x1: .65, y1: 0.0, x2: .25, y2: 1.0)),
      );
    case BravaisAlbumPart.hatch:
      return _frame(opacity: phase(480, 360, _out));
    case BravaisAlbumPart.dots:
    case BravaisAlbumPart.ghost:
      return _frame(opacity: phase(520, 600, _out));
    case BravaisAlbumPart.cover:
      final t = _phase(elapsed, 120, 560),
          p = _ease(_cover, t),
          opacity = _ease(_cover, (t / .6).clamp(0.0, 1.0));
      return _frame(
        opacity: opacity,
        y: -28 * (1 - p),
        scaleX: 1.14 - .14 * p,
        scaleY: 1.14 - .14 * p,
      );
    case BravaisAlbumPart.tape:
      final t = _phase(elapsed, 820, 300),
          scale = t <= .7
              ? 1.7 + (.94 - 1.7) * _ease(_tape, t / .7)
              : .94 + (1 - .94) * _ease(_tape, (t - .7) / .3);
      return _frame(
        opacity: _ease(_tape, (t / .7).clamp(0.0, 1.0)),
        scaleX: scale,
        scaleY: scale,
      );
    case BravaisAlbumPart.scrap:
      return _frame(opacity: .85 * phase(700, 500, _out));
    case BravaisAlbumPart.kicker:
      final p = phase(420, 380, _rise);
      return _frame(opacity: p, y: 14 * (1 - p));
    case BravaisAlbumPart.word:
      final p = phase(300 + index * 70, 520, _word),
          from = switch (index % 3) {
            1 => (x: .4, y: -.45, rotate: 7.0),
            2 => (x: 0.0, y: .6, rotate: 4.0),
            _ => (x: -.5, y: .35, rotate: -8.0),
          };
      // Word x/y stay in em; the host applies each word's actual computed font size.
      return _frame(
        opacity: p,
        x: from.x * (1 - p),
        y: from.y * (1 - p),
        rotate: from.rotate * (1 - p),
        em: true,
      );
    case BravaisAlbumPart.titleShadow:
      return _frame(progress: phase(640, 420, _out));
    case BravaisAlbumPart.underline:
      return _frame(
        scaleX: phase(620, 420, (x1: .6, y1: 0.0, x2: .2, y2: 1.0)),
      );
    case BravaisAlbumPart.bottom:
      final p = phase(index < 3 ? 560 + index * 60 : 740, 420, _rise);
      return _frame(opacity: p, y: 14 * (1 - p));
    case BravaisAlbumPart.top:
      return _frame(opacity: phase(200, 400, _out));
    case BravaisAlbumPart.root:
      return bravaisAlbumRest;
  }
}

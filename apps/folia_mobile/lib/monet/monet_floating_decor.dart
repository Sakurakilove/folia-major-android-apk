import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../rendering/folia_icons.dart';

// Complete MonetFloatingDecor.tsx tracks, including source-selected Lucide icons, petal veins and static mode.
class MonetDecorParticle {
  MonetDecorParticle(int i, List<String> icons)
    : id = i,
      x = ((i * 127 + 43) % 80) + 10.0,
      y = ((i * 211 + 17) % 80) + 5.0,
      size = 46.0 + (i * 53) % 40,
      rotation = (i * 97) % 360,
      duration = 20.0 + (i * 71) % 20,
      delay = ((i * 41) % 80) / 10,
      opacity = .06 + ((i * 31) % 12) / 100,
      iconName = icons.isNotEmpty && (i * 37 + 11) % 100 > 20
          ? icons[i % icons.length]
          : null,
      reverse = i.isEven;
  final int id, rotation;
  final double x, y, size, duration, delay, opacity;
  final String? iconName;
  final bool reverse;
}

class MonetFloatingDecor extends StatefulWidget {
  const MonetFloatingDecor({
    super.key,
    required this.secondaryColor,
    required this.lyricsIcons,
    required this.frames,
    required this.seconds,
    this.staticMode = false,
  });
  final Color secondaryColor;
  final List<String> lyricsIcons;
  final Listenable frames;
  final double Function() seconds;
  final bool staticMode;
  @override
  State<MonetFloatingDecor> createState() => _MonetFloatingDecorState();
}

class _MonetFloatingDecorState extends State<MonetFloatingDecor> {
  final _icons = <String, FoliaIconData?>{}, _pending = <String>{};
  final _static = _NoFrameSignal();
  late List<MonetDecorParticle> _particles;
  var _generation = 0;
  late double _born;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MonetFloatingDecor old) {
    super.didUpdateWidget(old);
    if (old.lyricsIcons.join(',') != widget.lyricsIcons.join(',')) _load();
    if (old.staticMode && !widget.staticMode) _born = widget.seconds();
  }

  void _load() {
    final generation = ++_generation;
    _born = widget.seconds();
    _particles = List.generate(
      10,
      (i) => MonetDecorParticle(i, widget.lyricsIcons),
      growable: false,
    );
    _icons.clear();
    _pending.clear();
    for (final name
        in _particles.map((p) => p.iconName).whereType<String>().toSet()) {
      _pending.add(name);
      FoliaIconRepository.shared
          .load(name)
          .then(
            (data) {
              if (!mounted || generation != _generation) return;
              setState(() {
                _pending.remove(name);
                _icons[name] = data;
              });
            },
            onError: (Object error) {
              if (!mounted || generation != _generation) return;
              setState(() {
                _pending.remove(name);
                _icons[name] = null;
              });
            },
          );
    }
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ClipRect(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _DecorPainter(
            _particles,
            _icons,
            _pending,
            widget.secondaryColor,
            () => widget.seconds() - _born,
            widget.staticMode,
            widget.staticMode ? _static : widget.frames,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _NoFrameSignal implements Listenable {
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _DecorPainter extends CustomPainter {
  _DecorPainter(
    this.particles,
    this.icons,
    this.pending,
    this.color,
    this.seconds,
    this.staticMode,
    Listenable frames,
  ) : super(repaint: frames);
  final List<MonetDecorParticle> particles;
  final Map<String, FoliaIconData?> icons;
  final Set<String> pending;
  final Color color;
  final double Function() seconds;
  final bool staticMode;
  static final _petal = Path()
    ..moveTo(12, 3)
    ..cubicTo(14.5, 5.5, 16.8, 9, 16, 14)
    ..cubicTo(15.2, 19, 13.5, 21, 12, 21)
    ..cubicTo(10.5, 21, 8.8, 19, 8, 14)
    ..cubicTo(7.2, 9, 9.5, 5.5, 12, 3)
    ..close();
  static final _vein = Path()
    ..moveTo(12, 6)
    ..cubicTo(12, 6, 11.3, 10.5, 11.3, 14.5)
    ..cubicTo(11.3, 17.5, 12, 20, 12, 20);
  static const _ease = Cubic(.42, 0, .58, 1), _alphas = [.6, 1.2, 1.0, 1.3, .7];
  static const _forwardX = [-15.0, 25.0, -10.0, 20.0, -15.0],
      _reverseX = [15.0, -25.0, 10.0, -20.0, 15.0];
  static const _forwardY = [40.0, -60.0, 20.0, -40.0, 40.0],
      _reverseY = [-40.0, 60.0, -20.0, 40.0, -40.0];
  static const _forwardTurn = [0.0, 120.0, 60.0, 180.0, 0.0],
      _reverseTurn = [0.0, -120.0, -60.0, -180.0, 0.0];
  double _lerp(List<double> values, int i, double t) =>
      values[i] + (values[i + 1] - values[i]) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final now = seconds();
    for (final p in particles) {
      if (p.iconName != null && pending.contains(p.iconName)) continue;
      final phase = math.max(0.0, now - p.delay) % p.duration / p.duration * 4;
      final segment = math.min(3, phase.floor()),
          t = _ease.transform(phase - segment);
      final x = staticMode
          ? 0.0
          : _lerp(p.reverse ? _reverseX : _forwardX, segment, t);
      final y = staticMode
          ? 0.0
          : _lerp(p.reverse ? _reverseY : _forwardY, segment, t);
      final angle =
          p.rotation +
          (staticMode
              ? 0
              : _lerp(p.reverse ? _reverseTurn : _forwardTurn, segment, t));
      final alpha = p.opacity * (staticMode ? 1 : _lerp(_alphas, segment, t));
      canvas.save();
      canvas.translate(size.width * p.x / 100 + x, size.height * p.y / 100 + y);
      canvas.translate(p.size / 2, p.size / 2);
      canvas.rotate(angle * math.pi / 180);
      canvas.translate(-p.size / 2, -p.size / 2);
      final icon = icons[p.iconName];
      if (icon != null) {
        icon.paint(
          canvas,
          p.size,
          color.withValues(alpha: color.a * alpha),
          strokeWidth: 1,
          absoluteStrokeWidth: true,
        );
      } else {
        canvas.scale(p.size / 24);
        canvas.drawPath(
          _petal,
          Paint()..color = color.withValues(alpha: .55 * alpha),
        );
        canvas.drawPath(
          _vein,
          Paint()
            ..color = color.withValues(alpha: .35 * alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .45
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DecorPainter old) => true;
}

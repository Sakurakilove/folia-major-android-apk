part of 'bravais_card_marks.dart';

// A finite native paint transition keeps CSS's shortened reversal on quick hover exits; the icon is retained throughout.
class _HideEye extends StatefulWidget {
  const _HideEye({
    required this.item,
    required this.strings,
    required this.accent,
    required this.onTap,
    required this.reducedMotion,
    required this.frames,
    required this.nowMs,
  });
  final BravaisItem item;
  final FoliaStrings strings;
  final Color accent;
  final VoidCallback onTap;
  final bool reducedMotion;
  final Listenable frames;
  final double Function() nowMs;
  @override
  State<_HideEye> createState() => _HideEyeState();
}

class _HideEyeState extends State<_HideEye> {
  late CssNumericSignal _alpha;
  @override
  void initState() {
    super.initState();
    _create(.45);
  }

  void _create(double initial) => _alpha = CssNumericSignal(
    initial,
    frames: widget.frames,
    nowMs: widget.nowMs,
  );
  @override
  void didUpdateWidget(_HideEye old) {
    super.didUpdateWidget(old);
    if (!identical(old.frames, widget.frames)) {
      final value = _alpha.value;
      _alpha.dispose();
      _create(value);
    } else {
      _alpha.nowMs = widget.nowMs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return BravaisControl(
      onPressed: w.onTap,
      toggled: w.item.hidden,
      label: w.strings.t(
        w.item.hidden ? 'libraryBravaisHome.unhide' : 'libraryBravaisHome.hide',
      ),
      builder: (_, hover, _) {
        _alpha.setTarget(
          hover ? .7 : .45,
          const CssTransitionSpec(140),
          enabled: !w.reducedMotion,
        );
        return CustomPaint(
          painter: _EyeBackground(_alpha),
          child: SizedBox.square(
            dimension: 34,
            child: Center(
              child: FoliaIcon(
                w.item.hidden ? 'EyeOff' : 'Eye',
                color: w.item.hidden ? w.accent : const Color(0xffffffff),
                size: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _alpha.dispose();
    super.dispose();
  }
}

class _EyeBackground extends CustomPainter {
  _EyeBackground(this.alpha) : super(repaint: alpha);
  final CssNumericSignal alpha;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    size.shortestSide / 2,
    Paint()..color = Color.from(alpha: alpha.value, red: 0, green: 0, blue: 0),
  );
  @override
  bool shouldRepaint(_EyeBackground old) => old.alpha != alpha;
}

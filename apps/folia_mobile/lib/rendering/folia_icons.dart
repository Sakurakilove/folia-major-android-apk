import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

part 'folia_prepared_icon.dart';

// Exact Lucide node data is exported at build time; SVG paths are parsed once, then painted natively.
class FoliaIconData {
  FoliaIconData.fromJson(Map<String, dynamic> data)
    : name = data['name'] as String,
      size = (data['size'] as num).toDouble(),
      _nodes = List.unmodifiable(
        (data['node'] as List).map((value) {
          final node = value as List,
              attributes = Map<String, dynamic>.from(node[1] as Map);
          return _IconNode(
            _path(node[0] as String, attributes),
            attributes['fill'] as String?,
          );
        }),
      );
  final String name;
  final double size;
  final List<_IconNode> _nodes;

  static Path _path(String tag, Map<String, dynamic> a) {
    double n(String key, [double fallback = 0]) {
      final value = a[key];
      return value == null
          ? fallback
          : value is num
          ? value.toDouble()
          : double.parse(value as String);
    }

    switch (tag) {
      case 'path':
        return parseSvgPathData(a['d'] as String);
      case 'circle':
        final r = n('r');
        return Path()..addOval(
          Rect.fromCircle(center: Offset(n('cx'), n('cy')), radius: r),
        );
      case 'ellipse':
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset(n('cx'), n('cy')),
            width: n('rx') * 2,
            height: n('ry') * 2,
          ),
        );
      case 'rect':
        final rx = n('rx', n('ry')), ry = n('ry', n('rx'));
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(n('x'), n('y'), n('width'), n('height')),
            Radius.elliptical(rx, ry),
          ),
        );
      case 'line':
        return Path()
          ..moveTo(n('x1'), n('y1'))
          ..lineTo(n('x2'), n('y2'));
      case 'polyline':
      case 'polygon':
        final values = (a['points'] as String)
            .trim()
            .split(RegExp(r'[\s,]+'))
            .map(double.parse)
            .toList();
        if (values.length.isOdd) {
          throw const FormatException('Odd SVG point coordinate count');
        }
        final path = Path();
        for (var i = 0; i < values.length; i += 2) {
          if (i == 0) {
            path.moveTo(values[i], values[i + 1]);
          } else {
            path.lineTo(values[i], values[i + 1]);
          }
        }
        if (tag == 'polygon') path.close();
        return path;
      default:
        throw FormatException('Unsupported original Lucide node: $tag');
    }
  }

  void paint(
    Canvas canvas,
    double pixels,
    Color color, {
    double strokeWidth = 2,
    bool absoluteStrokeWidth = false,
    bool filled = false,
  }) {
    if (pixels <= 0 || size <= 0) return;
    final scale = pixels / size;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = absoluteStrokeWidth ? strokeWidth / scale : strokeWidth;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.scale(scale);
    for (final node in _nodes) {
      final nodeFill = node.fill ?? (filled ? 'currentColor' : null);
      if (nodeFill != null && nodeFill != 'none') {
        if (nodeFill != 'currentColor') {
          throw FormatException('Unsupported Lucide fill: ${node.fill}');
        }
        canvas.drawPath(node.path, fill);
      }
      canvas.drawPath(node.path, stroke);
    }
    canvas.restore();
  }
}

class _IconNode {
  const _IconNode(this.path, this.fill);
  final Path path;
  final String? fill;
}

class FoliaIconRepository {
  FoliaIconRepository({AssetBundle? assets}) : _assets = assets ?? rootBundle;
  final AssetBundle _assets;
  Future<void>? _indexTask;
  final _names = <String, String>{}, _lowercase = <String, String>{};
  final _cache = <String, FoliaIconData>{};
  final _pending = <String, Future<FoliaIconData?>>{};
  static final shared = FoliaIconRepository();

  Future<void> _index() => _indexTask ??= _loadIndex();
  Future<void> _loadIndex() async {
    try {
      final data = jsonDecode(
        await _assets.loadString('assets/original/icons/index.json'),
      ) as Map;
      _names.addAll(Map<String, String>.from(data['names'] as Map));
      for (final name in _names.keys) {
        _lowercase.putIfAbsent(name.toLowerCase(), () => name);
      }
    } catch (_) {
      _indexTask = null;
      rethrow;
    }
  }

  Future<FoliaIconData?> load(String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    await _index();
    final clean = name.trim(),
        canonical = _names.containsKey(clean)
            ? clean
            : _lowercase[clean.toLowerCase()];
    final key = _names[canonical];
    if (key == null) return null;
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    return _pending[key] ??= _decode(key);
  }

  Future<FoliaIconData?> _decode(String key) async {
    try {
      final icon = FoliaIconData.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(
            await _assets.loadString(
              'assets/original/icons/$key.json',
              cache: false,
            ),
          ) as Map,
        ),
      );
      _cache[key] = icon;
      while (_cache.length > 256) {
        _cache.remove(_cache.keys.first);
      }
      return icon;
    } catch (error) {
      debugPrint('[FoliaIcons] $key: $error');
      return null;
    } finally {
      _pending.remove(key);
    }
  }

  Future<bool> hasExactName(String name) async {
    await _index();
    return _names.containsKey(name.trim());
  }
}

class FoliaIcon extends StatefulWidget {
  const FoliaIcon(
    this.name, {
    super.key,
    required this.color,
    this.size = 24,
    this.strokeWidth = 2,
    this.absoluteStrokeWidth = false,
    this.filled = false,
    this.semanticLabel,
  });
  final String name;
  final Color color;
  final double size, strokeWidth;
  final bool absoluteStrokeWidth, filled;
  final String? semanticLabel;
  @override
  State<FoliaIcon> createState() => _FoliaIconState();
}

class _FoliaIconState extends State<FoliaIcon> {
  late Future<FoliaIconData?> _data;
  @override
  void initState() {
    super.initState();
    _data = FoliaIconRepository.shared.load(widget.name);
  }

  @override
  void didUpdateWidget(FoliaIcon old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) {
      _data = FoliaIconRepository.shared.load(widget.name);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: widget.size,
      child: FutureBuilder<FoliaIconData?>(
        future: _data,
        builder: (context, value) => value.data == null
            ? const SizedBox.shrink()
            : CustomPaint(
                painter: _IconPainter(
                  value.data!,
                  widget.color,
                  widget.size,
                  widget.strokeWidth,
                  widget.absoluteStrokeWidth,
                  widget.filled,
                ),
              ),
      ),
    ),
  );
}

class _IconPainter extends CustomPainter {
  const _IconPainter(
    this.icon,
    this.color,
    this.pixels,
    this.stroke,
    this.absolute,
    this.filled,
  );
  final FoliaIconData icon;
  final Color color;
  final double pixels, stroke;
  final bool absolute, filled;
  @override
  void paint(Canvas canvas, Size size) => icon.paint(
    canvas,
    pixels,
    color,
    strokeWidth: stroke,
    absoluteStrokeWidth: absolute,
    filled: filled,
  );
  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon ||
      old.color != color ||
      old.pixels != pixels ||
      old.stroke != stroke ||
      old.absolute != absolute ||
      old.filled != filled;
}

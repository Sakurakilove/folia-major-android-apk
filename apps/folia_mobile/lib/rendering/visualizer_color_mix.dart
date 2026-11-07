import 'js_number.dart';
import 'js_text.dart';

// Preserve the original visualizer colorMix parser and its fallback/passthrough distinction. This deliberately differs from general CSS color resolution.
typedef VisualizerColorChannels = ({double r, double g, double b});

enum _ColorKind { channels, fallback, passthrough }

class _ParsedColor {
  const _ParsedColor(this.kind, [this.channels]);
  final _ColorKind kind;
  final VisualizerColorChannels? channels;
}

const _white = (r: 255.0, g: 255.0, b: 255.0);
final _cache = <String, _ParsedColor>{},
    _shortHex = RegExp(r'^[0-9a-fA-F]{3}$'),
    _longHex = RegExp(r'^[0-9a-fA-F]{6}$'),
    _rgb = RegExp(r'^rgba?\(([^)]+)\)$'),
    _number = RegExp(
      r'^[+-]?(?:Infinity|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)',
    );
double _float(String token) {
  final value = _number.firstMatch(jsTrim(token))?.group(0);
  return value == null ? double.nan : double.tryParse(value) ?? double.nan;
}

_ParsedColor _read(String color) {
  if (color.isEmpty) return const _ParsedColor(_ColorKind.fallback);
  if (color.startsWith('#')) {
    final hex = color.substring(1);
    if (_shortHex.hasMatch(hex)) {
      double byte(int i) =>
          int.parse('${hex[i]}${hex[i]}', radix: 16).toDouble();
      return _ParsedColor(_ColorKind.channels, (
        r: byte(0),
        g: byte(1),
        b: byte(2),
      ));
    }
    if (_longHex.hasMatch(hex)) {
      double byte(int i) =>
          int.parse(hex.substring(i, i + 2), radix: 16).toDouble();
      return _ParsedColor(_ColorKind.channels, (
        r: byte(0),
        g: byte(2),
        b: byte(4),
      ));
    }
    return const _ParsedColor(_ColorKind.fallback);
  }
  final match = _rgb.firstMatch(color);
  if (match != null) {
    final parts = match[1]!.split(',');
    final r = _float(parts.first),
        g = parts.length > 1 ? _float(parts[1]) : double.nan,
        b = parts.length > 2 ? _float(parts[2]) : double.nan;
    if (r.isFinite && g.isFinite && b.isFinite) {
      return _ParsedColor(_ColorKind.channels, (r: r, g: g, b: b));
    }
    return const _ParsedColor(_ColorKind.fallback);
  }
  return const _ParsedColor(_ColorKind.passthrough);
}

({String normalized, _ParsedColor parsed}) _parse(Object? color) {
  final normalized = color is String ? jsTrim(color) : '';
  var parsed = _cache[normalized];
  if (parsed == null) {
    parsed = _read(normalized);
    if (_cache.length >= 512) _cache.remove(_cache.keys.first);
    _cache[normalized] = parsed;
  }
  return (normalized: normalized, parsed: parsed);
}

double _clamp(double value, double min, double max) =>
    value.isNaN ? value : value.clamp(min, max);
String _format(VisualizerColorChannels channels, double alpha) =>
    'rgba(${jsNumberString(jsRound(_clamp(channels.r, 0, 255)))}, ${jsNumberString(jsRound(_clamp(channels.g, 0, 255)))}, ${jsNumberString(jsRound(_clamp(channels.b, 0, 255)))}, ${jsNumberString(alpha)})';
VisualizerColorChannels? visualizerColorChannels(Object? color) =>
    _parse(color).parsed.channels;
String visualizerColorWithAlpha(Object? color, double alpha) {
  final parsed = _parse(color);
  return parsed.parsed.kind == _ColorKind.passthrough
      ? parsed.normalized
      : _format(parsed.parsed.channels ?? _white, _clamp(alpha, 0, 1));
}

String mixVisualizerColors(
  String from,
  String to,
  double amount, [
  double alpha = 1,
]) {
  final t = _clamp(amount, 0, 1),
      a = _parse(from).parsed.channels,
      b = _parse(to).parsed.channels;
  if (a == null || b == null) {
    return visualizerColorWithAlpha(t >= .5 ? to : from, alpha);
  }
  // Unlike colorWithAlpha, the source mix does not clamp parsed RGB channels.
  String channel(double a, double b) =>
      jsNumberString(jsRound(a + (b - a) * t));
  return 'rgba(${channel(a.r, b.r)}, ${channel(a.g, b.g)}, ${channel(a.b, b.b)}, ${jsNumberString(_clamp(alpha, 0, 1))})';
}

import 'dart:math' as math;

import '../rendering/js_number.dart';
import '../rendering/js_text.dart';
import 'native_url.dart';

part 'cover_url_description.dart';

// Same source CDN buckets, original restoration and artwork identity; the parser preserves WHATWG escapes, opaque hosts and query serialization.
const coverSizeSteps = [256.0, 512.0, 1024.0];
const _nonResizable = {'blob:', 'data:', 'file:', 'filesystem:'};
final _dataImage = RegExp(r'^data:image/', caseSensitive: false);
final _kugouHost = RegExp(
      r'(?:^|\.)(?:kugou\.com|kgimg\.com)$',
      caseSensitive: false,
    ),
    _kugouPath = RegExp(r'(/stdmusic/)(\d+)(/)'),
    _kuwoHost = RegExp(r'^img\d*\.kuwo\.cn$', caseSensitive: false),
    _kuwoPath = RegExp(r'^(/star/(?:albumcover|starheads)/)(\d+)(/)'),
    _neteaseHost = RegExp(r'^p\d+\.music\.126\.net$', caseSensitive: false),
    _qqPath = RegExp(r'(T00[12])(?:R(\d+)x\d+)?(M000)');
double resolveCoverSizeStep(double size) =>
    coverSizeSteps.firstWhere((s) => s >= size, orElse: () => double.infinity);
double _roundedSize(double value) {
  if (value.isNaN) return value;
  final rounded = !value.isFinite || value.abs() >= 4503599627370496
      ? value
      : (value + .5).floorToDouble();
  return math.max(1, rounded);
}

double localCoverThumbnailSize(double size) =>
    _roundedSize(size) <= 512 ? 512 : 1024;
bool _isKugou(NativeUrl url) =>
    _kugouHost.hasMatch(url.hostname) && _kugouPath.hasMatch(url.pathname);
bool _isKuwo(NativeUrl url) =>
    _kuwoHost.hasMatch(url.hostname) && _kuwoPath.hasMatch(url.pathname);
bool _isQq(NativeUrl url) =>
    {'y.gtimg.cn', 'y.qq.com'}.contains(url.hostname) &&
    _qqPath.hasMatch(url.pathname);
String _pathSize(NativeUrl url, RegExp expression, String size) {
  url.pathname = url.pathname.replaceFirstMapped(
    expression,
    (m) => '${m[1]}$size${m[3]}',
  );
  return url.href;
}

String _qqSize(NativeUrl url, double? size) => _pathSize(
  url,
  _qqPath,
  size == null ? '' : 'R${jsNumberString(size)}x${jsNumberString(size)}',
);

class CoverUrlPolicy {
  CoverUrlPolicy(this.urls);
  final NativeUrlLibrary urls;
  final _cache = <(int, String, double), ({String value, int bytes})>{};
  int _cacheBytes = 0;
  static const _maxCacheBytes = 4 * 1024 * 1024;
  String _remember(
    int operation,
    String source,
    double size,
    String Function() build,
  ) {
    if (source.length * 2 > _maxCacheBytes) return build();
    final key = (operation, source, size), cached = _cache[key];
    if (cached != null) return cached.value;
    final result = build(), bytes = (source.length + result.length) * 2;
    if (bytes > _maxCacheBytes) return result;
    _cache[key] = (value: result, bytes: bytes);
    _cacheBytes += bytes;
    while (_cache.length > 2048 || _cacheBytes > _maxCacheBytes) {
      final oldest = _cache.keys.first;
      _cacheBytes -= _cache.remove(oldest)!.bytes;
    }
    return result;
  }

  String original(String? input) {
    final source = jsTrim(input ?? '');
    if (source.isEmpty) return '';
    if (_dataImage.hasMatch(source)) return source;
    return _remember(1, source, 0, () {
      final url = urls.parse(source);
      if (url == null) return source;
      try {
        if (_isKuwo(url)) {
          final original = double.parse(
            _kuwoPath.firstMatch(url.pathname)![2]!,
          );
          return _pathSize(
            url,
            _kuwoPath,
            jsNumberString(math.max(800, original)),
          );
        }
        return _isQq(url) ? _qqSize(url, null) : source;
      } finally {
        url.dispose();
      }
    });
  }

  String sized(String? input, double size) {
    final source = jsTrim(input ?? '');
    if (source.isEmpty) return '';
    if (_dataImage.hasMatch(source)) return source;
    return _remember(0, source, size, () {
      final normalized = _roundedSize(size), url = urls.parse(source);
      if (url == null) {
        if (source.startsWith('/__folia_cover/')) {
          final local = urls.parse(source, base: 'https://folia.local')!;
          try {
            local.setParameter(
              'size',
              jsNumberString(localCoverThumbnailSize(normalized)),
            );
            return local.pathname + local.search;
          } finally {
            local.dispose();
          }
        }
        return source.contains('126.net')
            ? '${source.split('?')[0]}?param=${jsNumberString(normalized)}y${jsNumberString(normalized)}'
            : source;
      }
      try {
        if (_nonResizable.contains(url.protocol)) return source;
        if (url.protocol == 'folia-cover:') {
          url.setParameter(
            'size',
            jsNumberString(localCoverThumbnailSize(normalized)),
          );
          return url.href;
        }
        if (_isKugou(url)) {
          return _pathSize(url, _kugouPath, jsNumberString(normalized));
        }
        if (_isKuwo(url)) {
          if (normalized <= 256) return _pathSize(url, _kuwoPath, '240');
          if (normalized <= 800) return _pathSize(url, _kuwoPath, '800');
          return original(source);
        }
        if (_isQq(url)) {
          return _qqSize(
            url,
            normalized <= 300
                ? 300
                : normalized <= 800
                ? 800
                : null,
          );
        }
        if (url.hostname.contains('126.net')) {
          return '${url.origin}${url.pathname}?param=${jsNumberString(normalized)}y${jsNumberString(normalized)}';
        }
        if (url.pathname.contains('getCoverArt')) {
          url.setParameter('size', jsNumberString(normalized));
          return url.href;
        }
        return source;
      } finally {
        url.dispose();
      }
    });
  }

  String identity(String? input) {
    final source = jsTrim(input ?? '');
    if (source.isEmpty) return '';
    if (_dataImage.hasMatch(source)) return source;
    return _remember(2, source, 0, () {
      final url = urls.parse(source);
      if (url != null) {
        try {
          if (_nonResizable.contains(url.protocol)) return source;
          if (_neteaseHost.hasMatch(url.hostname)) {
            return 'netease:${url.pathname}';
          }
          if (_isKugou(url)) {
            return 'kugou:${url.pathname.replaceFirstMapped(_kugouPath, (m) => '${m[1]}*${m[3]}')}';
          }
          if (_isKuwo(url)) {
            return 'kuwo:${url.pathname.replaceFirstMapped(_kuwoPath, (m) => '${m[1]}*${m[3]}')}';
          }
          if (_isQq(url)) {
            return 'qq:${url.pathname.replaceFirstMapped(_qqPath, (m) => '${m[1]}${m[3]}')}';
          }
        } finally {
          url.dispose();
        }
      }
      return source.split(RegExp('[?#]'))[0];
    });
  }
}

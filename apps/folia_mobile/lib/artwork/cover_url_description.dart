part of 'cover_url.dart';

// Diagnostics retain the original provider/size meaning; no credentials or URLs are written to logs.
class CoverUrlDescription {
  const CoverUrlDescription(this.provider, this.requestedSize);
  final String provider;
  final double? requestedSize;
  Map<String, Object?> toJson() => {
    'provider': provider,
    'requestedSize': requestedSize,
  };
}

final _decimalNumber = RegExp(
  r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$',
);
double? _parseSize(String? value) {
  final prefix = jsTrim(
    (value ?? '').split(RegExp('[xy]', caseSensitive: false))[0],
  );
  double? number;
  if (_decimalNumber.hasMatch(prefix)) {
    number = double.tryParse(prefix);
  } else {
    for (final entry in [
      (r'^0[xX][0-9a-fA-F]+$', 16),
      (r'^0[bB][01]+$', 2),
      (r'^0[oO][0-7]+$', 8),
    ]) {
      if (RegExp(entry.$1).hasMatch(prefix)) {
        number = BigInt.parse(prefix.substring(2), radix: entry.$2).toDouble();
        break;
      }
    }
  }
  return number != null && number.isFinite && number > 0 ? number : null;
}

extension CoverUrlDiagnostics on CoverUrlPolicy {
  CoverUrlDescription? describe(String? input) {
    final source = jsTrim(input ?? '');
    if (source.isEmpty || _dataImage.hasMatch(source)) return null;
    final url = urls.parse(source);
    if (url == null) {
      if (!source.startsWith('/__folia_cover/')) return null;
      final local = urls.parse(source, base: 'https://folia.local')!;
      try {
        return CoverUrlDescription(
          'local',
          _parseSize(local.parameter('size')),
        );
      } finally {
        local.dispose();
      }
    }
    try {
      if (_nonResizable.contains(url.protocol)) return null;
      if (url.protocol == 'folia-cover:') {
        return CoverUrlDescription('local', _parseSize(url.parameter('size')));
      }
      if (_isKugou(url)) {
        return CoverUrlDescription(
          'kugou',
          _parseSize(_kugouPath.firstMatch(url.pathname)![2]),
        );
      }
      if (_isKuwo(url)) {
        return CoverUrlDescription(
          'kuwo',
          _parseSize(_kuwoPath.firstMatch(url.pathname)![2]),
        );
      }
      if (_isQq(url)) {
        return CoverUrlDescription(
          'qq',
          _parseSize(_qqPath.firstMatch(url.pathname)![2]),
        );
      }
      if (url.hostname.contains('126.net')) {
        return CoverUrlDescription(
          'netease',
          _parseSize(url.parameter('param')),
        );
      }
      if (url.pathname.contains('getCoverArt')) {
        return CoverUrlDescription(
          'navidrome',
          _parseSize(url.parameter('size')),
        );
      }
      return const CoverUrlDescription('other', null);
    } finally {
      url.dispose();
    }
  }
}

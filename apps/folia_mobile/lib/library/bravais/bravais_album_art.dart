import 'dart:math' as math;
import 'dart:typed_data';

import '../../artwork/cover_url.dart';
import '../wall/wall_types.dart';
import 'tiles/bravais_item.dart';

// Original album-wall projection and detail selection. Float32 intermediates and stable score ties preserve source cut locations.
const bravaisAlbumMosaicPx = 12 * 136.0 - 8;
const bravaisFallbackCoverSpots = [
  WallPoint(.5, .5),
  WallPoint(.35, .4),
  WallPoint(.65, .6),
  WallPoint(.4, .65),
  WallPoint(.6, .35),
];

List<BravaisItem> assignAlbumCoverArt(
  List<BravaisItem> items,
  String? albumCoverUrl,
  CoverUrlPolicy urls,
) {
  final album = urls.identity(albumCoverUrl),
      covers = items
          .map((i) => urls.identity(i.coverUrl))
          .where((s) => s.isNotEmpty)
          .toSet();
  final single =
      covers.isEmpty ||
      covers.length == 1 && (album.isEmpty || covers.contains(album));
  if (single) {
    final url = albumCoverUrl != null && albumCoverUrl.isNotEmpty
        ? albumCoverUrl
        : items
              .map((i) => i.coverUrl)
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .firstOrNull;
    if (url == null) return items;
    final art = BravaisCoverArt(BravaisArtMode.mosaic, url);
    return items.map((i) => i.withArt(art)).toList(growable: false);
  }
  final seen = <String>{};
  return items
      .map((item) {
        final cover = urls.identity(item.coverUrl);
        if (cover.isEmpty) {
          return albumCoverUrl == null || albumCoverUrl.isEmpty
              ? item
              : item.withArt(
                  BravaisCoverArt(BravaisArtMode.shard, albumCoverUrl),
                  fallbackCover: albumCoverUrl,
                );
        }
        return seen.add(cover)
            ? item
            : item.withArt(
                BravaisCoverArt(BravaisArtMode.shard, item.coverUrl!),
              );
      })
      .toList(growable: false);
}

List<WallPoint> findBravaisCoverSpots(
  Uint8List pixels,
  int side, {
  int count = 6,
}) {
  final lum = Float32List(side * side), energy = Float32List(side * side);
  for (var i = 0; i < lum.length; i++) {
    lum[i] =
        .2126 * pixels[i * 4] +
        .7152 * pixels[i * 4 + 1] +
        .0722 * pixels[i * 4 + 2];
  }
  for (var y = 1; y < side - 1; y++) {
    for (var x = 1; x < side - 1; x++) {
      final i = y * side + x;
      energy[i] =
          (lum[i + 1] - lum[i - 1]).abs() +
          (lum[i + side] - lum[i - side]).abs();
    }
  }
  final window = math.max(4, (side / 5).round()),
      step = math.max(2, (window / 2).round());
  final candidates = <({WallPoint spot, double score, int index})>[];
  for (var top = 0; top + window <= side; top += step) {
    for (var left = 0; left + window <= side; left += step) {
      var score = 0.0;
      for (var y = top; y < top + window; y++) {
        for (var x = left; x < left + window; x++) {
          score += energy[y * side + x];
        }
      }
      candidates.add((
        spot: WallPoint((left + window / 2) / side, (top + window / 2) / side),
        score: score,
        index: candidates.length,
      ));
    }
  }
  candidates.sort((a, b) {
    final score = b.score.compareTo(a.score);
    return score == 0 ? a.index.compareTo(b.index) : score;
  });
  if (candidates.isEmpty || candidates.first.score <= 0) {
    return bravaisFallbackCoverSpots.take(count).toList(growable: false);
  }
  final gap = window / side, result = <WallPoint>[];
  for (final candidate in candidates) {
    if (candidate.score <= 0) break;
    if (result.any(
      (p) =>
          math.max(
            (p.x - candidate.spot.x).abs(),
            (p.y - candidate.spot.y).abs(),
          ) <
          gap,
    )) {
      continue;
    }
    result.add(candidate.spot);
    if (result.length >= count) break;
  }
  return result;
}

class BravaisArtPlacement {
  const BravaisArtPlacement(this.size, this.x, this.y);
  final double size, x, y;
}

BravaisArtPlacement bravaisMosaicPlacement(
  WallRect rect,
  int column,
  int row,
) => BravaisArtPlacement(
  bravaisAlbumMosaicPx,
  column * 12 * 136 - rect.x,
  row * 8 * 136 + ((8 * 136 - 8) - bravaisAlbumMosaicPx) / 2 - rect.y,
);

// Exact FNV-1a/imul/mulberry32 uses JS UTF-16 code units, including lone surrogates.
class BravaisPosterRandom {
  BravaisPosterRandom(String seed) {
    var hash = 2166136261;
    for (final unit in seed.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    _state = hash;
  }
  late int _state;
  double next() {
    _state = (_state + 0x6d2b79f5) & 0xffffffff;
    var value = ((_state ^ (_state >>> 15)) * (_state | 1)) & 0xffffffff;
    value ^=
        (value + (((value ^ (value >>> 7)) * (value | 61)) & 0xffffffff)) &
        0xffffffff;
    return ((value ^ (value >>> 14)) & 0xffffffff) / 4294967296;
  }
}

BravaisArtPlacement bravaisShardPlacement(
  List<WallPoint> spots,
  String seed,
  WallRect rect,
) {
  final random = BravaisPosterRandom('shard:$seed'),
      list = spots.isEmpty ? bravaisFallbackCoverSpots : spots;
  final spot = list[(random.next() * list.length).floor() % list.length],
      size = math.max(rect.width, rect.height) * (2 + 1.5 * random.next());
  double clamp(double value, double extent) =>
      math.min(0, math.max(extent - size, value));
  return BravaisArtPlacement(
    size,
    clamp(rect.width / 2 - spot.x * size, rect.width),
    clamp(rect.height / 2 - spot.y * size, rect.height),
  );
}

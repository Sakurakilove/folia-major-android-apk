// Complete original projected card data; provider/core resources remain behind the surface and are never reconstructed from display strings.
enum BravaisItemKind { track, playlist, album, artist, folder, feed }

enum BravaisTileForm { poster, stack, portrait }

enum BravaisTileKind { content, wall, window, heading }

enum BravaisArtMode { mosaic, shard }

enum BravaisSpecial {
  liked('Heart'),
  cloud('Cloud'),
  personalFm('Radio'),
  daily('CalendarDays'),
  allSongs('ListMusic'),
  localFavorites('Heart'),
  navidromeRandom('Shuffle'),
  navidromeFavorites('Star');

  const BravaisSpecial(this.icon);
  final String icon;
}

class BravaisCoverArt {
  const BravaisCoverArt(this.mode, this.url);
  final BravaisArtMode mode;
  final String url;
}

class BravaisItem {
  const BravaisItem({
    required this.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.coverUrl,
    this.coverArt,
    this.trackCountLabel,
    this.playbackKey,
    this.album,
    this.artists,
    this.durationLabel,
    this.unavailable = false,
    this.hideable = false,
    this.hidden = false,
    this.selected = false,
    this.dimmed = false,
    this.direct = false,
    this.special,
  });
  final String key, title, subtitle, badge;
  final BravaisItemKind kind;
  final String? coverUrl, trackCountLabel, playbackKey, album, durationLabel;
  final List<String>? artists;
  final BravaisCoverArt? coverArt;
  final bool unavailable, hideable, hidden, selected, dimmed, direct;
  final BravaisSpecial? special;
  BravaisTileForm get form => switch (kind) {
    BravaisItemKind.artist => BravaisTileForm.portrait,
    BravaisItemKind.album ||
    BravaisItemKind.playlist ||
    BravaisItemKind.folder => BravaisTileForm.stack,
    BravaisItemKind.feed =>
      direct ? BravaisTileForm.poster : BravaisTileForm.stack,
    _ => BravaisTileForm.poster,
  };
  String get accessibleName =>
      '$title · $subtitle${trackCountLabel == null || trackCountLabel!.isEmpty ? '' : ' · $trackCountLabel'}';
  BravaisItem withArt(BravaisCoverArt art, {String? fallbackCover}) =>
      BravaisItem(
        key: key,
        kind: kind,
        title: title,
        subtitle: subtitle,
        badge: badge,
        coverUrl: fallbackCover ?? coverUrl,
        coverArt: art,
        trackCountLabel: trackCountLabel,
        playbackKey: playbackKey,
        album: album,
        artists: artists,
        durationLabel: durationLabel,
        unavailable: unavailable,
        hideable: hideable,
        hidden: hidden,
        selected: selected,
        dimmed: dimmed,
        direct: direct,
        special: special,
      );
}

class BravaisCardFace {
  const BravaisCardFace(this.item, this.kind, {this.seeThrough = false});
  final BravaisItem? item;
  final BravaisTileKind kind;
  final bool seeThrough;
  String? get key => switch (kind) {
    BravaisTileKind.window => 'window',
    BravaisTileKind.wall => null,
    _ => item == null ? null : '${seeThrough ? '~' : ''}${item!.key}',
  };
}

int? resolveCollectionTrackCount(BravaisTileForm form, double? count) =>
    form == BravaisTileForm.stack &&
        count != null &&
        count.isFinite &&
        count > 0
    ? count.floor()
    : null;
String formatCollectionBadge(String kindLabel, int? count) =>
    count == null ? kindLabel : '$kindLabel · $count';

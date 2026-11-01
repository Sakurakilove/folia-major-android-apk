// A playback item retains every catalog/source field; queue persistence must not collapse it into four display strings.
class AudioTrack {
  AudioTrack(
    this.uri,
    this.title,
    this.artist,
    this.coverPath, {
    this.album = '',
    Map<String, dynamic> source = const {},
  }) : source = Map.unmodifiable(source);
  factory AudioTrack.fromMap(Map<String, dynamic> data) => AudioTrack(
    data['uri'] as String,
    data['title'] as String? ?? '',
    data['artist'] as String? ?? '',
    data['coverPath'] as String?,
    album: data['album'] as String? ?? '',
    source: data,
  );
  final String uri, title, artist, album;
  final String? coverPath;
  final Map<String, dynamic> source;
  Map<String, dynamic> toMap() => {
    ...source,
    'uri': uri,
    'title': title,
    'artist': artist,
    'album': album,
    'coverPath': coverPath,
  };
}

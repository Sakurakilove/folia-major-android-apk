part of 'bravais_album_entrance.dart';

// Finished parts retain their native layer: only a changed property record invalidates its consumer while other words are still entering.
class _AlbumMotionSignal extends ChangeNotifier
    implements ValueListenable<BravaisAlbumMotion> {
  _AlbumMotionSignal(this.owner, this.part, this.index);
  final BravaisAlbumEntrance owner;
  final BravaisAlbumPart part;
  final int index;
  BravaisAlbumMotion? _last;
  bool _attached = false;
  @override
  BravaisAlbumMotion get value => owner.sample(part, index);
  void _changed() {
    final next = value;
    if (next == _last) return;
    _last = next;
    notifyListeners();
    _sync();
  }

  void _sync() {
    final wanted = hasListeners;
    if (_attached == wanted) return;
    _attached = wanted;
    if (wanted) {
      owner.addListener(_changed);
      _last = value;
    } else {
      owner.removeListener(_changed);
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _sync();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _sync();
  }

  @override
  void dispose() {
    if (_attached) owner.removeListener(_changed);
    _attached = false;
    super.dispose();
  }
}

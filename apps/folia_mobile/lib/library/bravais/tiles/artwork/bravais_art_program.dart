import 'dart:ui' as ui;

// The real artwork shader is prepared before the wall's first-frame handoff. A shared one-pixel binding is only a sampler placeholder, never displayed artwork.
class BravaisArtProgram {
  BravaisArtProgram._(this.program, this.empty);
  final ui.FragmentProgram program;
  final ui.Image empty;
  bool _closed = false, _emptyClosed = false;
  final _shaders = <ui.FragmentShader>{};
  static Future<BravaisArtProgram> load() async {
    final program = await ui.FragmentProgram.fromAsset(
          'shaders/wall_artwork.frag',
        ),
        recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0x00000000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    try {
      return BravaisArtProgram._(program, await picture.toImage(1, 1));
    } finally {
      picture.dispose();
    }
  }

  ui.FragmentShader createShader() {
    if (_closed) throw StateError('Artwork program is closed');
    final shader = program.fragmentShader()..setImageSampler(0, empty);
    _shaders.add(shader);
    return shader;
  }

  void releaseShader(ui.FragmentShader shader) {
    if (_shaders.remove(shader)) shader.dispose();
    _releaseEmpty();
  }

  void _releaseEmpty() {
    if (_closed && !_emptyClosed && _shaders.isEmpty) {
      _emptyClosed = true;
      empty.dispose();
    }
  }

  void dispose() {
    _closed = true;
    _releaseEmpty();
  }
}

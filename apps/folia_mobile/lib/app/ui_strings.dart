// Initial shell text uses explicit locale keys; no English/Chinese strings are scattered through widgets.
class UiStrings {
  UiStrings(String language) : _text = _locales[language] ?? _locales['en']!;
  final Map<String, String> _text;
  String call(String key) => _text[key] ?? _locales['en']![key] ?? key;
  static const _locales = {
    'en': {
      'playbackError':
          'Unable to play this file. Reopen it or choose another track.',
      'library': 'Library',
      'openAudio': 'Open audio files',
      'openLyrics': 'Open lyrics',
      'player': 'Player',
      'empty': 'Choose local music to begin',
      'noLyrics': 'Open an LRC or YRC lyric file',
      'back': 'Back',
      'previous': 'Previous',
      'next': 'Next',
      'play': 'Play',
      'pause': 'Pause',
      'error': 'Unable to complete the action',
      'opticsFallback': 'This device renderer does not support optical shaders',
    },
    'zh': {
      'playbackError': '无法播放此文件，请重新打开或选择其他歌曲。',
      'library': '资料库',
      'openAudio': '打开音频文件',
      'openLyrics': '打开歌词',
      'player': '播放器',
      'empty': '选择本地音乐开始播放',
      'noLyrics': '打开 LRC 或 YRC 歌词文件',
      'back': '返回',
      'previous': '上一首',
      'next': '下一首',
      'play': '播放',
      'pause': '暂停',
      'error': '无法完成操作',
      'opticsFallback': '当前设备渲染后端不支持光学着色器',
    },
    'id': {
      'playbackError':
          'Berkas tidak dapat diputar. Buka lagi atau pilih lagu lain.',
      'library': 'Pustaka',
      'openAudio': 'Buka berkas audio',
      'openLyrics': 'Buka lirik',
      'player': 'Pemutar',
      'empty': 'Pilih musik lokal untuk mulai',
      'noLyrics': 'Buka berkas lirik LRC atau YRC',
      'back': 'Kembali',
      'previous': 'Sebelumnya',
      'next': 'Berikutnya',
      'play': 'Putar',
      'pause': 'Jeda',
      'error': 'Tidak dapat menyelesaikan tindakan',
      'opticsFallback': 'Perender perangkat ini tidak mendukung shader optik',
    },
  };
}

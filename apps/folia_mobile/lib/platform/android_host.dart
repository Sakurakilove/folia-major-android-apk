import 'package:flutter/services.dart';

// Only sparse state/clock anchors and user actions cross the Android boundary.
class AndroidHost {
  static const methods = MethodChannel('top.izuna.folia/native');
  static const events = EventChannel('top.izuna.folia/playback');
  static Future<List<Map<String, dynamic>>> pickAudio() async =>
      (await methods.invokeListMethod<dynamic>('pickAudio') ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  static Future<Map<String, dynamic>?> pickLyrics() async {
    final value = await methods.invokeMapMethod<String, dynamic>('pickLyrics');
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  static Future<void> command(String method, [Map<String, dynamic>? args]) =>
      methods.invokeMethod<void>(method, args);
}

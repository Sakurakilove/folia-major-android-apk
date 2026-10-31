# Folia Next — Flutter rewrite (migration preview)

Dart/Flutter owns the visible scene; Kotlin/Media3 owns playback, URI access and media services. The default client embeds neither Node nor WebView. This is an independently installable migration preview, not the completed replacement. Full parity and pending work: [FLUTTER_REWRITE.md](../../docs/android/FLUTTER_REWRITE.md).

Toolchain: Flutter 3.47.9 / Dart 3.13.7, Android SDK 37, JDK 21, NDK 28.2.13676358. Application ID: `top.izuna.foliamajor.next`.

```sh
flutter pub get
flutter analyze
# Small pure checks, no emulator:
dart run tool/check_motion.dart
# Release credentials stay outside the repository:
FOLIA_RELEASE_PROPERTIES=/absolute/path/to/keystore.properties flutter build apk --release --target-platform android-arm64
```

The release property file uses the existing Android signing format; relative store paths resolve from its adjacent `app` directory. Without external credentials, release output is unsigned and must not be delivered as a signed APK. Debug development uses `flutter run`.

Current slice: real SAF local audio and URI queue persistence, Kotlin Media3 playback/seek/pause/automatic next item/background audio/media session, LRC/YRC timing, zoom/pan viewport wall, cached full-DPR word/glow masks, native painter animation, and finite optical backdrop with Kyant-derived seven-color dispersion. Only the word/tone/particle math is ported so far; subtitles, all visual settings, portrait/frame variants, exit/handover details, keyword colors, all other styles/backgrounds, online accounts, full EQ/effects/automix and mod compatibility are pending. Typography/visual parity, startup and power require real-device comparison. Do not call this the full rewrite or claim a watt reduction from APK size.

A static idle library has no animation ticker. Hidden Flutter rendering stops while native audio continues. Continuous clocks repaint bounded painters; they do not set widget state per frame. Raster/texture caches preserve DPR and source resolution, pin visible work and evict unused images. Hardware without shader-filter support shows a visible material fallback notice; it does not claim full optics.

All source remains under the repository's AGPL-3.0 license. Kyant shader provenance and Apache-2.0 license are also shipped as app assets.

# Folia — implementation migration (not ready for delivery)

The complete frontend is in scope for rewriting, with every original feature, appearance, interaction and animation preserved. The root [AGENTS.md](../../AGENTS.md) defines the mandatory delivery gate: complete the entire rewrite, compare against the original, fix all discrepancies, then deliver. The simplified alpha.1 UI fails this requirement and has been withdrawn as a migration candidate; its code is an internal architecture experiment. Original production sources remain the comparison baseline. Full parity and pending work: [FLUTTER_REWRITE.md](../../docs/android/FLUTTER_REWRITE.md).

Toolchain: Flutter 3.47.9 / Dart 3.13.7, Android SDK 37, JDK 21, NDK 28.2.13676358. Application ID: `top.izuna.foliamajor.next`.

```sh
flutter pub get
flutter analyze
# Small pure checks, no emulator:
dart run tool/check_motion.dart
dart run tool/check_lyric_reference.dart
dart run tool/check_monet_audio_reference.dart
dart run tool/check_scene_transition_reference.dart
# Release credentials stay outside the repository:
FOLIA_RELEASE_PROPERTIES=/absolute/path/to/keystore.properties flutter build apk --release --target-platform android-arm64
```

The release property file uses the existing Android signing format; relative store paths resolve from its adjacent `app` directory. Without external credentials, release output is unsigned and must not be delivered as a signed APK. Debug development uses `flutter run`.

The original normalized lyric schema, render hints, syllable/grapheme timing, token/keyword ranges, subtitle selection, rail geometry, font-stack rules and portrait-layer ordering now have native counterparts. `tool/check_lyric_reference.dart` compares them with values from the actual TypeScript functions. Its synthetic text metrics isolate geometry; it does not prove native font shaping or visual parity. The native portrait widget, typography adapter, original locale/default/icon resources and Lucide path renderer are under integration. Full pages, settings, styles/backgrounds, online accounts, complete audio effects and mod compatibility remain unfinished. No replacement APK is ready for delivery.

Generated original resources live in `assets/original` and must not be hand-edited. From a checkout with the root Node dependencies installed, run `node apps/folia_mobile/tool/export_original_assets.cjs`; the generator copies original locale values, uses the existing Taiwan conversion utility, preserves original defaults and exports the installed Lucide vector nodes and license. `provenance.json` records source hashes. `node apps/folia_mobile/tool/generate_lyric_reference.cjs` regenerates the pure-rule differential fixture. Node is a build-time tool for these generators and is not embedded in the new app.

A static idle library has no animation ticker. Hidden Flutter rendering stops while native audio continues. Continuous clocks repaint bounded painters; they do not set widget state per frame. Raster/texture caches preserve DPR and source resolution, pin visible work and evict unused images. Hardware without shader-filter support shows a visible material fallback notice; it does not claim full optics.

All source remains under the repository's AGPL-3.0 license. Kyant shader provenance and Apache-2.0 license are also shipped as app assets.

The faithful `monet/page/monet_poster_scene.dart` and independent `still` components are under integration; the experiment root is still not the original full client. The shared `visualizer/transitions` host ports original first-frame/rapid-switch/soft-focus rules. Native PCM/FFT analysis lives under Android `analysis`/`cpp`, with one shared Dart FFI snapshot and no per-frame channel audio payload. Disabled analysis performs no FFT or periodic worker wakeups; the existing audio thread retains bounded PCM history for a prompt resume. Complete post-effects/resampling parity remains pending. Current compile/pure-state checks do not certify visual fidelity or watts.

Before replacement delivery, from the repository root run `python3 apps/folia_mobile/tool/migration_catalog.py check`; it must currently refuse delivery. It checks coverage/evidence records, not whether a claimed visual observation is true. Keep all unresolved pages, modes, backgrounds, settings, providers, effects, mods and data paths unresolved until actually migrated and compared.

Shared native subtitles now include the original exit retention, two tracks, local radial glow, upcoming text/filter transitions and direct bottom signal. `tool/export_css_case.cjs` regenerates full Unicode uppercase constants with provenance; `cssNormalText` preserves CSS whitespace rules. Unicode version/locale differences remain subject to final browser comparison. Motion's duration/bounce/visual-duration spring resolution is present; this does not complete all property/compositor adapters or style integration.

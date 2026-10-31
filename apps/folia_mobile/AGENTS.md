# Flutter rewrite rules

- This app is the Flutter/Dart + Kotlin replacement under active migration. Read root WORKLOG.md and docs/android/FLUTTER_REWRITE.md before continuing. Do not call an incomplete migration a complete client.
- Use official Dart naming: lower_snake_case files, UpperCamelCase types, lowerCamelCase members; Kotlin follows Kotlin conventions. Keep feature code together.
- Preserve all baseline animation curves, clocks, glow, blur, refraction/dispersion, typography and input behavior. No lower frame rate, render scale, particle count or static substitute to claim efficiency.
- Continuous time drives Listenable/CustomPainter repaint, never whole-widget setState per frame. Only visible scenes own frame scheduling; stop when hidden and release image/shader/audio resources explicitly.
- Cache measured glyphs and their exact blur layers by font, font variation, DPI and layout. Cache capacity is a memory bound, not permission to reduce image resolution.
- Android audio, URI access, foreground/media services, keys and system integration belong in Kotlin. Platform channel messages are state/clock anchors or bounded chunks, never per-frame image/audio payloads.
- No always-running WebView or embedded Node in this app. Optional legacy mod compatibility must be isolated and documented before it can count as migrated.
- New install identity is isolated until data/key migration and feature parity are accepted. Do not clear or silently rewrite the old app's credentials.
- Follow the user's reduced-testing preference: analyzer, native/release compile, signature/resource checks and the smallest meaningful deterministic animation checks. No emulator or full UI suite by default.

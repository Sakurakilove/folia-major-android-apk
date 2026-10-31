# Flutter rewrite rules

- **用户硬性要求：功能、界面和动画全部保留，只改变底层实现；只有在保证前端没有任何外观上的改变时，才可以重写前端代码。必须严格遵守根目录 AGENTS.md 顶部的全部迁移约束，本目录不得例外。**
- This app is an internal Flutter/Dart + Kotlin architecture experiment. Alpha.1 fails the original client's feature and visual parity requirements; do not extend its simplified UI or deliver it as a migration candidate. Read root AGENTS.md, WORKLOG.md and docs/android/FLUTTER_REWRITE.md before continuing; root parity requirements supersede older preview plans.
- Use official Dart naming: lower_snake_case files, UpperCamelCase types, lowerCamelCase members; Kotlin follows Kotlin conventions. Keep feature code together.
- Preserve all baseline animation curves, clocks, glow, blur, refraction/dispersion, typography and input behavior. No lower frame rate, render scale, particle count or static substitute to claim efficiency.
- Continuous time drives Listenable/CustomPainter repaint, never whole-widget setState per frame. Only visible scenes own frame scheduling; stop when hidden and release image/shader/audio resources explicitly.
- Cache measured glyphs and their exact blur layers by font, font variation, DPI and layout. Cache capacity is a memory bound, not permission to reduce image resolution.
- Android audio, URI access, foreground/media services, keys and system integration belong in Kotlin. Platform channel messages are state/clock anchors or bounded chunks, never per-frame image/audio payloads.
- Reducing runtime overhead is subordinate to preserving every feature, appearance and animation. Preserve the original frontend until a replacement is proven equivalent; retaining it takes priority over removing WebView/Node or keeping Flutter. Mod compatibility is mandatory for parity, not optional.
- New install identity is isolated until data/key migration and feature parity are accepted. Do not clear or silently rewrite the old app's credentials.
- Follow the user's reduced-testing preference: analyzer, native/release compile, signature/resource checks and the smallest meaningful deterministic animation checks. No emulator or full UI suite by default.

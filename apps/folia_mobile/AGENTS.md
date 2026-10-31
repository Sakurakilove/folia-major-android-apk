# Flutter rewrite rules

- **用户硬性要求：功能、界面和动画全部保留，只改变底层实现。前端代码也必须完成重写，保证没有任何外观上的改变；全部重写迁移完成后，检查前端严格遵照原版，确认一致后才可交付。必须严格遵守根目录 AGENTS.md 顶部的全部迁移约束，本目录不得例外。**
- This app is an internal Flutter/Dart + Kotlin architecture experiment. Alpha.1 fails the original client's feature and visual parity requirements; do not extend its simplified UI or deliver it as a migration candidate. Read root AGENTS.md, WORKLOG.md and docs/android/FLUTTER_REWRITE.md before continuing; root parity requirements supersede older preview plans.
- Use official Dart naming: lower_snake_case files, UpperCamelCase types, lowerCamelCase members; Kotlin follows Kotlin conventions. Keep feature code together.
- Preserve all baseline animation curves, clocks, glow, blur, refraction/dispersion, typography and input behavior. No lower frame rate, render scale, particle count or static substitute to claim efficiency.
- Continuous time drives Listenable/CustomPainter repaint, never whole-widget setState per frame. Only visible scenes own frame scheduling; stop when hidden and release image/shader/audio resources explicitly.
- Cache measured glyphs and their exact blur layers by font, font variation, DPI and layout. Cache capacity is a memory bound, not permission to reduce image resolution.
- Android audio, URI access, foreground/media services, keys and system integration belong in Kotlin. Platform channel messages are state/clock anchors or bounded chunks, never per-frame image/audio payloads.
- The frontend rewrite is required, with every feature, appearance, interaction and animation preserved. Keep the original as the comparison baseline, not as a substitute for completing the rewrite. After the entire migration, verify strict parity and fix every discrepancy before delivery; framework choices and removing WebView/Node cannot override this gate. Mod compatibility is mandatory for parity, not optional.
- New install identity is isolated until data/key migration and feature parity are accepted. Do not clear or silently rewrite the old app's credentials.
- Follow the user's reduced-testing preference: analyzer, native/release compile, signature/resource checks and the smallest meaningful deterministic animation checks. No emulator or full UI suite by default.

# Chromium CSS timing facts

`ChromiumCssBezier.sampleUnit` ports the original unit-interval algorithm from
Chromium `154.0.8037.57`, not an arbitrarily higher-precision Bézier solver.
The source uses eleven spline samples, four Newton iterations, then bisection,
with its original `1e-7` stopping criterion. Y overshoot is preserved; property
clamps happen separately. Only unit-interval input is implemented here.

Pinned source files and SHA-256:

- `ui/gfx/geometry/cubic_bezier.cc`:
  `9eac76cf4ae7d41940bf4e4d4061526aab8e312b39f035eb17d472793cd01b10`
- `ui/gfx/geometry/cubic_bezier.h`:
  `263d2dc134e1911225e7ea9390d1a00c2889478d618338705c3b9aa969bc0eef`
- `third_party/blink/renderer/platform/animation/timing_function.cc`:
  `453beed257eb699a6b2836a80ee12b8a4b844ab90119e48cc0b7674897dac631`
- `third_party/blink/renderer/core/animation/interpolable_length.cc`:
  `5c2307bd35a9ee1811fc8e6ac686d3cc1fe615a774f8b289af27babb2e7951bc`

Fetch from `https://raw.githubusercontent.com/chromium/chromium/154.0.8037.57/`.
The bundled BSD license is `assets/Chromium-LICENSE.txt` (repository path).

CSS animation easing is per property-specific keyframe segment; WAAPI effect
and per-keyframe easing remain distinct. Resolved CSS Length and opacity use
float32 before painting and computed-style serialization. Word em translations
must resolve with the word's actual font size before that conversion.

The current isolated album observations use six-significant-digit CSS computed
style, not a full visual/device acceptance result. Existing generic `cssBezier`
callers have not all been audited or switched; Motion's JS curve solver remains
separate. Preserve the full original animation paths while continuing that audit.

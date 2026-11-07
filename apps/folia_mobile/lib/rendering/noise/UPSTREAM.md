# SVG noise source

The native static-texture kernel ports the seed-0, two-octave fractal-noise
table and sampling used by Skia, not a visually similar random texture.
Source license: [Skia license](../../../assets/Skia-LICENSE.txt), BSD-3-Clause, Google Inc.

Chromium `154.0.8037.57` pins Skia
`2466dcf3937437e217e7f284afe0e1aae15891ce` in its `DEPS` file.
Relevant pinned files and SHA-256:

- `src/shaders/SkPerlinNoiseShaderImpl.h`:
  `f1284a779376bcdbeed21b5430c1636cf1ceaea1260803e12093a3753ffe92a8`
- `src/opts/SkRasterPipeline_opts.h`:
  `849ecf600bf6181fc44f101e4c84c451fba13b00f12dbfbe64bd035fc1803541`
- `src/core/SkPoint.cpp`:
  `57df91f691a187f524ff1859d1c3877ddcb04561eeb7d1f52933ab878217cf5a`

Fetch from `https://raw.githubusercontent.com/google/skia/<revision>/<path>`.
The native port preserves float32 gradients/coordinates, permutation order,
stitch-frequency selection and premultiplied RGBA8 intermediate storage.
The original SVG's default filter region is 120% of its bounding box. Gamma,
color-matrix and opacity operations follow that intermediate in the renderer.

This component is **under migration**, not final pixel acceptance. The initial
manual gamma/opacity implementation differed from Chromium and was removed.
Native composition now keeps the RGBA8 intermediate and a separate opacity
layer; forty source samples at DPR 1/2 are checked. Concrete CSS background
sizing, all DPR values and actual material/device composition still require
comparison before use in a delivery build.

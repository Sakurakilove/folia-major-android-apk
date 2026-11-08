# CSS layout precision

`cssLayoutUnit` follows the signed 26.6 `LayoutUnit` constructor in Chromium
`154.0.8037.57`. Floating input saturates to signed 32-bit raw units and truncates
toward zero. Negative overflowing flex centering must not use `floor`.
`cssFloat32` remains separate: computed CSS lengths and percentage values have
their own float conversion before fixed layout, while transforms do not acquire
another 1/64-pixel layout snap.

Pinned source:

- `third_party/blink/renderer/platform/geometry/layout_unit.h`
- SHA-256: `fdc4e8d9386923943ec92a6868dcf59b34c741d52b19d0ee41c255092ff23624`
- https://raw.githubusercontent.com/chromium/chromium/154.0.8037.57/third_party/blink/renderer/platform/geometry/layout_unit.h
- BSD notice: `assets/Blink-LICENSE.txt`.

Current consumers are the album figure/tape and album UI flex skeleton.
Five controlled original CSS content-box layouts strictly match their native
coordinates and sizes, including collapsed stages and signed overflow.
The tape's layout percentage is quantized before its half-width CSS transform;
the transform itself retains the fractional half unit.

This is not acceptance of all CSS sizing, fonts, browser versions, dynamic
pages or Android pixels. Original JavaScript world geometry must not be snapped
merely because CSS layout uses this representation. All existing layout paths
still require their own source comparison.

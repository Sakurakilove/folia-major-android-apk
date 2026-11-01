import 'dart:math' as math;

// Shared original playerBottomBarLayout.ts geometry: direct baseline dragging and independently sprung presence must not be mixed.
const playerBottomBarBaseOffsetPx = 32.0;
const playerBottomBarSubtitleClearancePx = 80.0;

double resolvePlayerBottomBarMaxOffset(double height) =>
    !height.isFinite || height <= 0
    ? playerBottomBarBaseOffsetPx
    : math.max(
        playerBottomBarBaseOffsetPx,
        (height * .5 - 132 + .5).floorToDouble(),
      );
double clampPlayerBottomBarOffset(double offset, double height) =>
    !offset.isFinite
    ? playerBottomBarBaseOffsetPx
    : (offset + .5).floorToDouble().clamp(
        playerBottomBarBaseOffsetPx,
        resolvePlayerBottomBarMaxOffset(height),
      );
double resolvePlayerBottomComponentBottom(
  double offset,
  double componentBase,
) => componentBase + offset - playerBottomBarBaseOffsetPx;
double resolvePlayerSubtitleBottomFromPresence(
  double offset,
  double presence,
) =>
    playerBottomBarBaseOffsetPx +
    presence *
        ((offset - playerBottomBarBaseOffsetPx) +
            playerBottomBarSubtitleClearancePx);

// usePlayerSubtitleBottomPx: Android measured clearance wins on the real player; previews retain their own default baseline.
double resolveSubtitleBottom({
  required bool isPlayerHost,
  required double offset,
  required double presence,
  required bool isAndroid,
  required double androidClearance,
}) => isAndroid && isPlayerHost && androidClearance > 0
    ? androidClearance
    : resolvePlayerSubtitleBottomFromPresence(
        isPlayerHost ? offset : playerBottomBarBaseOffsetPx,
        presence,
      );

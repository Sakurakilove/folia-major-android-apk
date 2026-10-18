import type { LatticeCamera } from './useWallCameraPan';

// Keep the world point between two fingers anchored while the camera scales and pans.
export type WallTouch = { x: number; y: number };
export const wallTouchPair = (points: WallTouch[]) => ({
    x: (points[0].x + points[1].x) / 2,
    y: (points[0].y + points[1].y) / 2,
    distance: Math.max(1, Math.hypot(points[1].x - points[0].x, points[1].y - points[0].y)),
});
export const pinchWallCamera = (camera: LatticeCamera, start: ReturnType<typeof wallTouchPair>, next: ReturnType<typeof wallTouchPair>): LatticeCamera => {
    const scale = Math.max(0.32, Math.min(1.8, camera.scale * next.distance / start.distance));
    const ratio = scale / camera.scale;
    return { scale, x: next.x - (start.x - camera.x) * ratio, y: next.y - (start.y - camera.y) * ratio };
};

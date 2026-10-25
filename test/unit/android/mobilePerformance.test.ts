import { describe, expect, it } from 'vitest';
import { createRequire } from 'node:module';
import { createFrameRateLimitedRaf } from '../../../src/utils/frameRateLimiter';
import { pinchWallCamera, wallTouchPair } from '../../../src/components/wall/wallPinch';

// Phone optimizations must preserve gesture anchors and deferred work instead of dropping callbacks.
const require = createRequire(import.meta.url);
const lazyBackend = require('../../../packaging/android/runtime/lazyBackend.cjs');
describe('phone interaction and idle work', () => {
    it('keeps the world point at the pinch centroid anchored while translating', () => {
        const from = { x: -20, y: -10, scale: 0.5 };
        const start = wallTouchPair([{ x: 50, y: 50 }, { x: 150, y: 50 }]);
        const next = wallTouchPair([{ x: 40, y: 70 }, { x: 240, y: 70 }]);
        const camera = pinchWallCamera(from, start, next);
        expect(camera.scale).toBe(1);
        expect((next.x - camera.x) / camera.scale).toBe((start.x - from.x) / from.scale);
        expect((next.y - camera.y) / camera.scale).toBe((start.y - from.y) / from.scale);
        expect(pinchWallCamera(from, start, { ...next, distance: 10000 }).scale).toBe(1.8);
        expect(pinchWallCamera(from, start, { ...next, distance: 1 }).scale).toBe(0.32);
    });
    it('retains pending animation work while suspended and wakes it on resume', () => {
        let tick: FrameRequestCallback | undefined;
        let scheduled = 0;
        let calls = 0;
        const raf = createFrameRateLimitedRaf(callback => { tick = callback; return ++scheduled; }, () => { tick = undefined; }, 60);
        raf.setSuspended(true);
        raf.requestAnimationFrame(() => { calls++; });
        expect(scheduled).toBe(0);
        raf.setSuspended(false);
        tick?.(20);
        expect(calls).toBe(1);
        raf.requestAnimationFrame(() => { calls++; });
        tick?.(36);
        expect(calls).toBe(2);
    });
    it('starts a platform once for concurrent first requests and stays idle until requested', async () => {
        let starts = 0;
        let port: number | null = null;
        const readPort = lazyBackend({ getPort: () => port, start: async () => { starts++; await Promise.resolve(); port = 12000; } });
        expect(starts).toBe(0);
        expect(await Promise.all([readPort(), readPort(), readPort()])).toEqual([12000, 12000, 12000]);
        expect(starts).toBe(1);
        expect(await readPort()).toBe(12000);
        expect(starts).toBe(1);
    });
    it('can retry a failed first platform startup', async () => {
        let starts = 0;
        const readPort = lazyBackend({ getPort: () => null, start: async () => { if (++starts === 1) throw new Error('offline'); } });
        await expect(readPort()).rejects.toThrow('offline');
        await expect(readPort()).resolves.toBeNull();
        expect(starts).toBe(2);
    });
});

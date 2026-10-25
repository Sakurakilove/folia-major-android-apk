import { expect, it } from 'vitest';
import { createWallArtworkQueue } from '@/components/wall/wallArtworkQueue';
import { BRAVAIS_BLOCK_SHAPE, collectShapeSlots } from '@/library/suites/bravais/bravaisWallShape';

// Check resource limits and viewport priority without running a device or visual suite.
it('bounds concurrent decodes and continues after a failed request', async () => {
    const queue = createWallArtworkQueue(2);
    let active = 0;
    let peak = 0;
    const jobs = Array.from({ length: 12 }, (_, index) => queue(async () => {
        active++;
        peak = Math.max(peak, active);
        await Promise.resolve();
        active--;
        if (index === 0) throw new Error('decode failed');
        return index;
    }));
    const results = await Promise.allSettled(jobs);
    expect(peak).toBe(2);
    expect(results.filter(result => result.status === 'fulfilled')).toHaveLength(11);
});

it('spends the tile budget on the viewport before overscan without duplicating slots', () => {
    const visible = { left: 500, right: 1800, top: 500, bottom: 1800 };
    const bounds = { left: -3000, right: 3000, top: -3000, bottom: 3000 };
    const expected = collectShapeSlots(BRAVAIS_BLOCK_SHAPE, visible, 3);
    expect(expected).toHaveLength(3);
    expect(collectShapeSlots(BRAVAIS_BLOCK_SHAPE, bounds, 3, visible)).toEqual(expected);
    const slots = collectShapeSlots(BRAVAIS_BLOCK_SHAPE, bounds, 100, visible);
    expect(new Set(slots.map(slot => slot.key)).size).toBe(slots.length);
    expect(collectShapeSlots(BRAVAIS_BLOCK_SHAPE, bounds, 0, visible)).toEqual([]);
});

it('removes an abandoned queued decode and leaves capacity for the next visible request', async () => {
    const queue = createWallArtworkQueue(1, 1);
    let release!: () => void;
    const first = queue(() => new Promise<void>(resolve => { release = resolve; }));
    await Promise.resolve();
    const controller = new AbortController();
    let obsoleteRan = false;
    const obsolete = queue(async () => { obsoleteRan = true; }, controller.signal).catch(error => error);
    controller.abort();
    expect((await obsolete).name).toBe('AbortError');
    const visible = queue(async () => 42);
    release();
    await first;
    expect(await visible).toBe(42);
    expect(obsoleteRan).toBe(false);
});

it('keeps retained tile order stable when viewport priority changes during a pan', () => {
    const bounds = { left: -600, right: 1800, top: -600, bottom: 1800 };
    const first = collectShapeSlots(BRAVAIS_BLOCK_SHAPE, bounds, 400, { left: 100, right: 600, top: 100, bottom: 700 });
    const next = collectShapeSlots(BRAVAIS_BLOCK_SHAPE, bounds, 400, { left: 300, right: 800, top: 300, bottom: 900 });
    const firstKeys = new Set(first.map(slot => slot.key));
    const nextKeys = new Set(next.map(slot => slot.key));
    expect(first.filter(slot => nextKeys.has(slot.key)).map(slot => slot.key))
        .toEqual(next.filter(slot => firstKeys.has(slot.key)).map(slot => slot.key));
});

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

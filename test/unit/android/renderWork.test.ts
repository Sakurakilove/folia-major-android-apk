import { describe, expect, it, vi } from 'vitest';
import type { Line } from '../../../src/types';
import { createActiveLineLookup } from '../../../src/utils/lyrics/activeLineIndex';
import { findLatestActiveLineIndex } from '../../../src/utils/appPlaybackHelpers';
import { stableWallSlots } from '../../../src/components/wall/stableWallSlots';
import { BRAVAIS_BLOCK_SHAPE, collectShapeSlots } from '../../../src/library/suites/bravais/bravaisWallShape';

// Verify reduced work preserves overlapping lyric timing and stable wall geometry/order.
describe('Android rendering work reuse', () => {
    it('matches the original latest-active lookup across overlaps, gaps, equal starts and tails', () => {
        const lines = Array.from({ length: 600 }, (_, index) => ({
            startTime: Math.floor(index / 2) * 2,
            endTime: Math.floor(index / 2) * 2 + (index % 9 === 0 ? 40 : 1),
            ...(index % 5 === 0 ? { renderHints: { renderEndTime: Math.floor(index / 2) * 2 + 6 } } : {}),
        } as Line));
        const lookup = createActiveLineLookup(lines);
        for (let time = -2; time <= 650; time += 0.25) expect(lookup(time), String(time)).toBe(findLatestActiveLineIndex(lines, time));
    });
    it('retains fallback semantics for unsorted lyrics and nonfinite clocks', () => {
        const lines = [{ startTime: 9, endTime: 10 }, { startTime: 0, endTime: 20 }] as Line[];
        const lookup = createActiveLineLookup(lines);
        for (const time of [-1, 0, 9, 10, 11, 20, 21, Infinity, -Infinity, NaN]) expect(lookup(time)).toBe(findLatestActiveLineIndex(lines, time));
        expect(createActiveLineLookup([])(1)).toBe(-1);
    });
    it('reuses only complete geometry equality and preserves ordered presentation', () => {
        const bounds = { left: -500, top: -500, right: 1200, bottom: 1200 };
        const first = collectShapeSlots(BRAVAIS_BLOCK_SHAPE, bounds, 64);
        const same = first.map(slot => ({ ...slot }));
        expect(stableWallSlots(same, first)).toBe(first);
        const moved = same.map((slot, index) => index === 0 ? { ...slot, width: slot.width + 1 } : slot);
        expect(stableWallSlots(moved, first)).toBe(moved);
        const footprint = same.map((slot, index) => index === 0 ? { ...slot, area: slot.area + 1 } : slot);
        expect(stableWallSlots(footprint, first)).toBe(footprint);
        const reverse = [...same].reverse();
        expect(stableWallSlots(reverse, first)).toBe(reverse);
    });
    it('builds each block once across the visible and overscan selection passes', () => {
        const blockSlots = vi.fn(BRAVAIS_BLOCK_SHAPE.blockSlots);
        const bounds = { left: -500, top: -500, right: 1200, bottom: 1200 };
        const visible = { left: 0, top: 0, right: 400, bottom: 600 };
        const selected = collectShapeSlots({ ...BRAVAIS_BLOCK_SHAPE, blockSlots }, bounds, 200, visible);
        expect(selected).toEqual(collectShapeSlots(BRAVAIS_BLOCK_SHAPE, bounds, 200, visible));
        const blocks = blockSlots.mock.calls.map(args => args.join(':'));
        expect(blocks.length).toBe(new Set(blocks).size);
    });
});

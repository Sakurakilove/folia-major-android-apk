import type { WallSlot } from './wallSlots';

// Preserve presentation identity when a recull selected exactly the same immutable geometry.
export const stableWallSlots = (next: readonly WallSlot[], previous: readonly WallSlot[]): readonly WallSlot[] => {
    if (next.length !== previous.length) return next;
    for (let index = 0; index < next.length; index++) {
        const a = next[index];
        const b = previous[index];
        if (a.key !== b.key || a.x !== b.x || a.y !== b.y || a.width !== b.width || a.height !== b.height
            || a.area !== b.area || a.centerX !== b.centerX || a.centerY !== b.centerY || a.column !== b.column || a.row !== b.row || a.slotIndex !== b.slotIndex) return next;
    }
    return previous;
};

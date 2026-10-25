import { useLayoutEffect, type RefObject } from 'react';
import { runsOnAndroid } from '../../utils/platform';

// Materialize wall tiles at their committed pixel size; continuous camera motion only composites that basis.
export const readWallRasterScale = (element: HTMLElement | null): number => {
    const scale = Number(element?.dataset.foliaRasterScale);
    return Number.isFinite(scale) && scale > 0 ? scale : 1;
};
export const useWallRasterization = (
    refs: readonly RefObject<HTMLDivElement | null>[],
    committedScale: number | null,
    redraw: () => void,
): void => {
    useLayoutEffect(() => {
        if (!runsOnAndroid() || committedScale === null || committedScale <= 0) return;
        for (const ref of refs) {
            const world = ref.current;
            if (!world) continue;
            world.dataset.foliaRasterScale = String(committedScale);
            world.style.setProperty('--folia-raster-scale', String(committedScale));
        }
        // Children zoom and the inverse camera correction must reach the same paint.
        redraw();
    }, [committedScale, redraw, refs]);
};

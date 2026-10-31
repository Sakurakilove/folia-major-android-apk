import { useEffect, useState } from 'react';
import { runsOnAndroid } from '../../utils/platform';
import { cancelUncappedAnimationFrame, requestUncappedAnimationFrame } from '../../utils/frameRateLimiter';
import { waitForAndroidVisualState } from './useAndroidSurfaceReady';

// Allocate a finite overlay's glass layer before starting its original compositor animation.
export const useAndroidOverlayReady = (): boolean => {
    const android = runsOnAndroid();
    const [ready, setReady] = useState(!android);
    useEffect(() => {
        if (!android) return;
        let cancelled = false;
        let frame = requestUncappedAnimationFrame(() => {
            frame = 0;
            void waitForAndroidVisualState().catch(error => {
                console.warn('[AndroidOverlay] Visual-state fence failed', error);
            }).then(() => {
                if (!cancelled) frame = requestUncappedAnimationFrame(() => { if (!cancelled) setReady(true); });
            });
        });
        return () => { cancelled = true; if (frame) cancelUncappedAnimationFrame(frame); };
    }, [android]);
    return ready;
};

import { useEffect } from 'react';
import { registerPlugin } from '@capacitor/core';
import { runsOnAndroid } from '../../utils/platform';

// Theme changes update the native background behind transparent status and navigation bars.
const native = registerPlugin<{ systemBars(options: { background: string; darkIcons: boolean }): Promise<void> }>('FoliaRuntime');
export const useAndroidSystemBars = (background: string, isDaylight: boolean): void => {
    useEffect(() => {
        if (!runsOnAndroid()) return;
        void native.systemBars({ background, darkIcons: isDaylight })
            .catch(error => console.warn('[AndroidSystemBars] Cannot update system bars', error));
    }, [background, isDaylight]);
};

// Music continues at full quality while a stationary library needs fewer presentation frames.
export const useAndroidPlayerVisibility = (isPlayerView: boolean): void => {
    useEffect(() => {
        if (!runsOnAndroid()) return;
        document.documentElement.dataset.foliaPlayerView = String(isPlayerView);
        window.dispatchEvent(new Event('folia-player-view-changed'));
    }, [isPlayerView]);
};

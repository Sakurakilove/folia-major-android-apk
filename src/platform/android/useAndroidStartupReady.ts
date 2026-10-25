import { useEffect } from 'react';
import { runsOnAndroid } from '../../utils/platform';
import { waitForAndroidVisualState } from './useAndroidSurfaceReady';

// Release the original splash only after a real main-app surface can replace it.
export const useAndroidStartupReady = (view: string, surfaceReady: boolean): void => {
    useEffect(() => {
        if (!runsOnAndroid() || document.documentElement.dataset.foliaFirstSurfaceReady === 'true') return;
        let stopped = false;
        let waiting = false;
        const publish = () => {
            if (stopped || waiting) return;
            if (!surfaceReady && !(view === 'lattice' && document.querySelector('.lattice-queue-root'))) return;
            waiting = true;
            void waitForAndroidVisualState().then(() => {
                if (stopped) return;
                document.documentElement.dataset.foliaFirstSurfaceReady = 'true';
                window.dispatchEvent(new Event('folia-first-surface-ready'));
            }).catch(error => { if (!stopped) console.warn('[AndroidSurface] Startup frame was not confirmed:', error); });
        };
        const observer = new MutationObserver(publish);
        if (view === 'lattice') observer.observe(document.getElementById('root') ?? document.body, { childList: true, subtree: true });
        publish();
        return () => { stopped = true; observer.disconnect(); };
    }, [surfaceReady, view]);
};

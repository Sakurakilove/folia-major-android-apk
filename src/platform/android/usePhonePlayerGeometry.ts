import { useEffect, type RefObject } from 'react';
import { publishAndroidPlayerClearance } from './androidPlayerGeometry';

// Measure the phone bar without a second rendering surface or a playback-clock subscription.
export const usePhonePlayerGeometry = (ref: RefObject<HTMLDivElement | null>): void => {
    useEffect(() => {
        const panel = ref.current?.closest<HTMLElement>('[data-folia-mobile-player-panel]');
        const outer = panel?.closest<HTMLElement>('[data-folia-mobile-player]');
        if (!panel || !outer) return;
        let frame: number | undefined;
        const sync = () => {
            frame = undefined;
            const rect = panel.getBoundingClientRect();
            const visible = outer.dataset.foliaPlayerState === 'visible' && !document.hidden && rect.width > 0 && rect.height > 0;
            publishAndroidPlayerClearance(visible ? window.innerHeight - rect.top + 12 : 0);
        };
        const schedule = () => { if (frame === undefined) frame = requestAnimationFrame(sync); };
        const resize = new ResizeObserver(schedule);
        resize.observe(panel);
        const changes = new MutationObserver(schedule);
        changes.observe(outer, { attributes: true, attributeFilter: ['data-folia-player-state', 'style'] });
        window.addEventListener('resize', schedule);
        document.addEventListener('visibilitychange', schedule);
        schedule();
        return () => {
            if (frame !== undefined) cancelAnimationFrame(frame);
            resize.disconnect(); changes.disconnect();
            window.removeEventListener('resize', schedule);
            document.removeEventListener('visibilitychange', schedule);
            publishAndroidPlayerClearance(0);
        };
    }, [ref]);
};

import { useEffect, useRef, type RefObject } from 'react';
import { Capacitor, registerPlugin, type PluginListenerHandle } from '@capacitor/core';
import type { ExpandedViewProps } from '../../components/FloatingPlayerControls';
import { PlayerState } from '../../types';
import { publishAndroidPlayerClearance } from './androidPlayerGeometry';

// The native material and controls reuse the existing DOM actions, including user-configured slots.
const native = registerPlugin<{
    liquidPlayer(options: Record<string, unknown>): Promise<{ active: boolean }>;
    addListener(event: 'liquidPlayerAction', callback: (event: { action: string; position: number }) => void): Promise<PluginListenerHandle>;
}>('FoliaRuntime');
const actionSelector = (action: string) => action === 'primary' || action === 'secondary'
    ? `[data-folia-native-slot="${action}"] button` : `[data-folia-native-action="${action}"]`;
export const useNativeLiquidPlayer = (ref: RefObject<HTMLDivElement | null>, props: ExpandedViewProps): void => {
    const current = useRef(props);
    current.current = props;
    const refresh = useRef<(() => void) | null>(null);
    useEffect(() => { refresh.current?.(); });
    useEffect(() => {
        const root = ref.current;
        const panel = root?.closest<HTMLElement>('[data-folia-mobile-player-panel]');
        const outer = root?.closest<HTMLElement>('[data-folia-mobile-player]');
        if (!root || !panel || !outer) return;
        const supported = Capacitor.isNativePlatform() && Capacitor.getPlatform() === 'android';
        let disposed = false;
        let pending = false;
        let dirty = false;
        let scheduled: ReturnType<typeof setTimeout> | undefined;
        let sample = true;
        let lastSample = 0;
        let lastClock = 0;
        let listener: Promise<PluginListenerHandle> | undefined;
        const sync = async () => {
            scheduled = undefined;
            if (disposed) return;
            if (pending) { dirty = true; return; }
            const state = outer.dataset.foliaPlayerState;
            const rect = panel.getBoundingClientRect();
            const visible = state === 'visible' && rect.width > 0 && rect.height > 0 && !document.hidden;
            publishAndroidPlayerClearance(visible ? window.innerHeight - rect.top + 12 : 0);
            if (!supported) return;
            // Native views sit over WebView. Hide this one whenever a DOM sheet/dialog covers its hit area.
            const uncovered = [0.1, 0.5, 0.9].every(x => [0.2, 0.8].every(y => {
                const hit = document.elementFromPoint(rect.left + rect.width * x, rect.top + rect.height * y);
                return Boolean(hit && panel.contains(hit));
            }));
            const modal = Array.from(document.querySelectorAll<HTMLElement>('[role="dialog"], [role="menu"], [data-folia-settings-overlay]')).some(element => {
                const bounds = element.getBoundingClientRect();
                const style = getComputedStyle(element);
                return !element.closest('[aria-hidden="true"], [inert]') && bounds.width > 0 && bounds.height > 0
                    && bounds.bottom > 0 && bounds.top < window.innerHeight && bounds.right > 0 && bounds.left < window.innerWidth
                    && style.visibility !== 'hidden' && Number.parseFloat(style.opacity) > 0;
            });
            let show = visible && uncovered && !modal && document.documentElement.dataset.foliaFloating !== 'true';
            const data = current.current;
            const buttons: Record<string, unknown> = {};
            for (const action of ['prev', 'play', 'next', 'primary', 'secondary']) {
                const button = root.querySelector<HTMLButtonElement>(actionSelector(action));
                if (!button) continue;
                const svg = button.querySelector('svg')?.cloneNode(true) as SVGSVGElement | undefined;
                svg?.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
                buttons[action] = { label: button.getAttribute('aria-label') || button.title, disabled: button.disabled,
                    active: button.className.includes('bg-white/20') || button.className.includes('bg-black/10'),
                    svg: svg?.outerHTML.replace(/currentColor/g, '#ffffff') || '' };
            }
            // Mod-provided extra actions remain usable on the original web surface.
            if (root.querySelectorAll('button').length > Object.keys(buttons).length || root.querySelectorAll('input').length > 1) show = false;
            const color = getComputedStyle(root).color.match(/[\d.]+/g)?.map(Number) ?? [255, 255, 255];
            if (show) panel.dataset.foliaNativeGlass = 'pending';
            const shouldSample = sample;
            sample = false;
            pending = true;
            try {
                const result = await native.liquidPlayer({ visible: show, viewportWidth: window.innerWidth,
                    x: rect.left, y: rect.top, width: rect.width, height: rect.height, sample: shouldSample,
                    title: data.currentSong?.name || data.noTrackText,
                    artist: data.currentSong?.artists?.map(artist => artist.name).join(' / ') || '',
                    ink: (255 << 24) | (color[0] << 16) | (color[1] << 8) | color[2],
                    daylight: Boolean(data.isDaylight), playing: data.playerState === PlayerState.PLAYING,
                    disabled: Boolean(data.controlsDisabled), position: data.currentTime.get(), duration: data.duration,
                    seekLabel: root.dataset.foliaSeekLabel || '', buttons });
                if (!disposed) {
                    if (result.active) panel.dataset.foliaNativeGlass = 'active';
                    else delete panel.dataset.foliaNativeGlass;
                }
            } catch (error) {
                delete panel.dataset.foliaNativeGlass;
                console.warn('[AndroidGlass] Native player unavailable', error);
            } finally {
                pending = false;
                if (dirty) { dirty = false; schedule(); }
            }
        };
        const schedule = () => { if (!disposed && scheduled === undefined) scheduled = setTimeout(() => { void sync(); }, 50); };
        refresh.current = schedule;
        const sampleInteraction = (event: PointerEvent) => {
            if (event.type === 'pointermove' && !event.buttons) return;
            if (performance.now() - lastSample < 200) return;
            lastSample = performance.now(); sample = true; schedule();
        };
        const resize = new ResizeObserver(() => { sample = true; schedule(); });
        resize.observe(panel);
        const outerChanges = new MutationObserver(schedule);
        outerChanges.observe(outer, { attributes: true, attributeFilter: ['data-folia-player-state', 'style'] });
        const portals = new MutationObserver(schedule);
        portals.observe(document.body, { childList: true, subtree: true });
        const stopClock = props.currentTime.on('change', () => {
            if (performance.now() - lastClock < 1000) return;
            lastClock = performance.now(); schedule();
        });
        if (supported) listener = native.addListener('liquidPlayerAction', event => {
            if (event.action === 'seek') { if (!current.current.controlsDisabled) current.current.onSeek(event.position); }
            else if (event.action === 'open') root.click();
            else if (['prev', 'play', 'next', 'primary', 'secondary'].includes(event.action)) root.querySelector<HTMLButtonElement>(actionSelector(event.action))?.click();
        });
        for (const name of ['pointerdown', 'pointermove', 'pointerup'] as const) document.addEventListener(name, sampleInteraction, { passive: true });
        document.addEventListener('visibilitychange', schedule);
        window.addEventListener('resize', schedule);
        schedule();
        return () => {
            disposed = true; refresh.current = null;
            clearTimeout(scheduled); resize.disconnect(); outerChanges.disconnect(); portals.disconnect(); stopClock();
            for (const name of ['pointerdown', 'pointermove', 'pointerup'] as const) document.removeEventListener(name, sampleInteraction);
            document.removeEventListener('visibilitychange', schedule); window.removeEventListener('resize', schedule);
            delete panel.dataset.foliaNativeGlass;
            publishAndroidPlayerClearance(0);
            void listener?.then(handle => handle.remove());
            if (supported) void native.liquidPlayer({ visible: false }).catch(() => {});
        };
    }, [ref, props.currentTime]);
};

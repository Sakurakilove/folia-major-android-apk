import { useEffect, useRef, useState, type RefObject } from 'react';
import { registerPlugin } from '@capacitor/core';
import { runsOnAndroid } from '../../utils/platform';

// Prepare returning surfaces before releasing their animated predecessor; never capture/draw a second WebView.
const renderer = registerPlugin<{ visualState(): Promise<void> }>('FoliaRuntime');
export const waitForAndroidVisualState = (): Promise<void> => runsOnAndroid() ? renderer.visualState() : Promise.resolve();
const nextFrame = (): Promise<void> => new Promise(resolve => requestAnimationFrame(() => resolve()));
// Lazy surfaces and the wall's measured layout must exist before collecting artwork or fencing a frame.
const waitForHomeContent = (root: HTMLElement, signal: AbortSignal): Promise<void> => new Promise((resolve, reject) => {
    const ready = () => Boolean(root.querySelector('[data-folia-home-content-ready]'))
        && (!root.querySelector('[data-library-home="bravais"]') || Boolean(root.querySelector('[data-bravais-layer]')));
    const finish = () => { observer.disconnect(); signal.removeEventListener('abort', abort); resolve(); };
    const abort = () => { observer.disconnect(); reject(new DOMException('Surface preparation cancelled', 'AbortError')); };
    const observer = new MutationObserver(() => { if (ready()) finish(); });
    if (signal.aborted) { abort(); return; }
    if (ready()) { finish(); return; }
    observer.observe(root, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-bravais-layer'] });
    signal.addEventListener('abort', abort, { once: true });
});
const visibleArtwork = (root: HTMLElement): string[] => {
    const urls = new Set<string>();
    for (const element of root.querySelectorAll<HTMLElement>('img, .lattice-poster')) {
        const box = element.getBoundingClientRect();
        if (box.width <= 0 || box.height <= 0 || box.bottom <= 0 || box.right <= 0 || box.top >= innerHeight || box.left >= innerWidth) continue;
        if (element instanceof HTMLImageElement) { if (element.currentSrc || element.src) urls.add(element.currentSrc || element.src); }
        else {
            const background = getComputedStyle(element).backgroundImage;
            for (const match of background.matchAll(/url\((?:"([^"]*)"|'([^']*)'|([^)]*))\)/g)) {
                const url = (match[1] ?? match[2] ?? match[3] ?? '').trim();
                if (url) urls.add(url);
            }
        }
    }
    return [...urls];
};
const decodeArtwork = async (urls: string[], signal: AbortSignal): Promise<void> => {
    let cursor = 0;
    const load = async () => {
        while (!signal.aborted && cursor < urls.length) {
            const url = urls[cursor++];
            const image = new Image(); image.decoding = 'async';
            const cancel = () => { image.src = ''; };
            signal.addEventListener('abort', cancel, { once: true });
            const timer = setTimeout(cancel, 15000);
            try {
                if (typeof image.decode === 'function') { image.src = url; await image.decode(); }
                else await new Promise<void>(resolve => { image.onload = () => resolve(); image.onerror = () => resolve(); image.src = url; });
            }
            catch { /* The surface's normal cover placeholder is still a valid frame on network failure. */ }
            finally { clearTimeout(timer); signal.removeEventListener('abort', cancel); image.onload = null; image.onerror = null; }
        }
    };
    await Promise.all([load(), load(), load()]);
};
export const useAndroidSurfaceReady = (ref: RefObject<HTMLElement | null>, requested: boolean, mounted: boolean, bypass = false): boolean => {
    const android = runsOnAndroid();
    // The startup splash also waits for this handshake; a React commit alone is not a ready frame.
    const [ready, setReady] = useState(requested && !android);
    const current = useRef(0);
    useEffect(() => {
        const generation = ++current.current;
        if (!android || bypass) { setReady(requested); return; }
        if (!requested) { setReady(false); return; }
        if (ready || !mounted) return;
        const controller = new AbortController();
        const prepare = async () => {
            await nextFrame();
            const root = ref.current;
            if (!root || controller.signal.aborted) return;
            await waitForHomeContent(root, controller.signal);
            await nextFrame();
            if (controller.signal.aborted) return;
            await decodeArtwork(visibleArtwork(root), controller.signal);
            if (controller.signal.aborted) return;
            await renderer.visualState();
            if (!controller.signal.aborted && generation === current.current) setReady(true);
        };
        void prepare().catch(error => {
            if (!controller.signal.aborted) console.warn('[AndroidSurface] Waiting for a presentable frame failed:', error);
        });
        return () => controller.abort();
    }, [android, bypass, mounted, ready, ref, requested]);
    return !android || bypass ? requested : requested && ready;
};

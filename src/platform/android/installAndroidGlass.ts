import { registerPlugin } from '@capacitor/core';
import { cancelUncappedAnimationFrame, requestUncappedAnimationFrame } from '../../utils/frameRateLimiter';

// Publish optical geometry only when UI layout changes; native RenderEffect consumes every real frame.
const selector = '.folia-glass-surface, .st-window, .st-pop, .lattice-tools-panel, .lattice-tools-island, [data-folia-native-glass]';
type Surface = { x: number; y: number; width: number; height: number; radius: number; opacity: number };
const native = registerPlugin<{ opticalGlass(options: { viewportWidth: number; surfaces: Surface[] }): Promise<{ active: boolean }> }>('FoliaRuntime');
let installed = false;

export const installAndroidGlass = (): void => {
    if (installed) return;
    installed = true;
    let frame = 0;
    let sending = false;
    let dirty = false;
    let previous = '';
    let epoch = 0;
    let ancestors = new Map<Element, string>();
    const observed = new Set<Element>();
    const geometryStyle = (element: Element) => {
        const style = (element as HTMLElement).style;
        return [style.transform, style.translate, style.scale, style.opacity, style.display, style.visibility,
            style.width, style.height, style.top, style.left, style.right, style.bottom].join('|');
    };
    const schedule = () => {
        dirty = true;
        if (!frame && !sending) frame = requestUncappedAnimationFrame(sync);
    };
    const resize = new ResizeObserver(schedule);
    const sync = () => {
        frame = 0;
        dirty = false;
        const nextObserved = new Set<Element>();
        const nextAncestors = new Map<Element, string>();
        const surfaces: Array<Surface & { z: number; order: number }> = [];
        let order = 0;
        for (const node of document.querySelectorAll<HTMLElement>(selector)) {
            nextObserved.add(node);
            if (!observed.has(node)) resize.observe(node);
            const box = node.getBoundingClientRect();
            if (box.width < 12 || box.height < 12 || box.bottom <= 0 || box.right <= 0 || box.top >= innerHeight || box.left >= innerWidth) continue;
            const style = getComputedStyle(node);
            if (style.display === 'none' || style.visibility !== 'visible') continue;
            let opacity = 1;
            let z = 0;
            for (let parent: HTMLElement | null = node; parent; parent = parent.parentElement) {
                nextAncestors.set(parent, geometryStyle(parent));
                const parentStyle = parent === node ? style : getComputedStyle(parent);
                opacity *= Number(parentStyle.opacity);
                z = Math.max(z, Number.parseInt(parentStyle.zIndex) || 0);
            }
            if (opacity < 0.01) continue;
            const rounded = (value: number) => Math.round(value * 4) / 4;
            const radius = Math.min(Number.parseFloat(style.borderTopLeftRadius) || 0, Math.min(box.width, box.height) / 2);
            surfaces.push({ x: rounded(box.x), y: rounded(box.y), width: rounded(box.width), height: rounded(box.height), radius: rounded(radius), opacity, z, order: order++ });
        }
        for (const node of observed) if (!nextObserved.has(node)) resize.unobserve(node);
        observed.clear(); for (const node of nextObserved) observed.add(node);
        ancestors = nextAncestors;
        // Topmost windows precede the transport behind them; one pixel receives optics only once.
        const selected = document.hidden ? [] : surfaces.sort((a, b) => b.z - a.z || b.order - a.order).slice(0, 8)
            .map(({ z: _z, order: _order, ...surface }) => surface);
        const payload = { viewportWidth: innerWidth, surfaces: selected };
        const signature = JSON.stringify(payload);
        if (signature === previous) return;
        sending = true;
        const sentEpoch = epoch;
        void native.opticalGlass(payload).then(result => {
            if (sentEpoch !== epoch) return;
            previous = signature;
            document.documentElement.dataset.foliaNativeOptics = String(result.active);
        }).catch(error => console.warn('[AndroidGlass] Cannot update optical geometry', error)).finally(() => {
            sending = false;
            if (dirty && !document.hidden) schedule();
        });
    };
    const mutations = new MutationObserver(records => {
        for (const record of records) {
            if (record.type === 'attributes' && record.target instanceof Element && ancestors.has(record.target)) {
                if (record.attributeName !== 'style' || ancestors.get(record.target) !== geometryStyle(record.target)) { schedule(); return; }
            }
            if (record.type === 'childList') {
                for (const node of [...record.addedNodes, ...record.removedNodes]) {
                    if (node instanceof Element && (observed.has(node) || node.matches(selector) || node.querySelector(selector))) { schedule(); return; }
                }
            }
        }
    });
    mutations.observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ['style', 'class', 'hidden'] });
    window.addEventListener('resize', schedule);
    document.addEventListener('visibilitychange', schedule);
    window.addEventListener('pagehide', () => {
        epoch++;
        if (frame) { cancelUncappedAnimationFrame(frame); frame = 0; }
        void native.opticalGlass({ viewportWidth: innerWidth, surfaces: [] });
        previous = '';
    });
    window.addEventListener('pageshow', schedule);
    schedule();
};

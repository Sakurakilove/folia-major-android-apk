import type { PluginListenerHandle } from '@capacitor/core';

// Keep cancelled gestures reversible; commit exactly one layer using the app's existing close/history paths.
interface BackEvent {
    phase: 'start' | 'progress' | 'cancel' | 'commit';
    progress: number;
    edge?: number;
}

interface AndroidBackPlugin {
    backState(options: { enabled: boolean }): Promise<void>;
    addListener(event: 'backGesture', listener: (event: BackEvent) => void): Promise<PluginListenerHandle>;
}

const visibleDialogs = (): HTMLElement[] => [...document.querySelectorAll<HTMLElement>('[role="dialog"], [role="menu"], [role="listbox"]')]
    .filter(element => element.getClientRects().length > 0 && element.getAttribute('aria-hidden') !== 'true');

export const hasAndroidBackDestination = (historyIndex: unknown, overlayCount: number): boolean => (
    overlayCount > 0 || (typeof historyIndex === 'number' && Number.isInteger(historyIndex) && historyIndex > 0)
);

export const installAndroidBack = (runtime: AndroidBackPlugin): void => {
    let target: HTMLElement | null = null;
    let savedTranslate = '';
    let savedScale = '';
    let frame = 0;
    let pending: BackEvent | null = null;
    let lastEnabled: boolean | null = null;
    const sync = () => {
        const enabled = hasAndroidBackDestination(window.history.state?.appHistoryIndex, visibleDialogs().length);
        if (lastEnabled === enabled) return;
        lastEnabled = enabled;
        void runtime.backState({ enabled }).catch(error => console.warn('[AndroidBack] Cannot update navigation state', error));
    };
    const restore = (animate: boolean) => {
        cancelAnimationFrame(frame);
        frame = 0;
        pending = null;
        if (!target) return;
        const currentTranslate = target.style.translate;
        const currentScale = target.style.scale;
        target.style.translate = savedTranslate;
        target.style.scale = savedScale;
        if (animate) target.animate([
            { translate: currentTranslate, scale: currentScale },
            { translate: savedTranslate || '0px', scale: savedScale || '1' },
        ], { duration: 180, easing: 'cubic-bezier(0.2, 0, 0, 1)' });
        target = null;
    };
    void runtime.addListener('backGesture', event => {
        if (event.phase === 'start') {
            restore(false);
            target = visibleDialogs().at(-1) ?? document.getElementById('root');
            if (target) { savedTranslate = target.style.translate; savedScale = target.style.scale; }
        } else if (event.phase === 'progress') {
            pending = event;
            if (frame) return;
            frame = requestAnimationFrame(() => {
                frame = 0;
                if (!target || !pending) return;
                const progress = Math.max(0, Math.min(1, pending.progress));
                const direction = pending.edge === 1 ? -1 : 1;
                target.style.translate = `${direction * progress * Math.min(window.innerWidth * 0.08, 48)}px 0px`;
                target.style.scale = String(1 - 0.04 * progress);
            });
        } else if (event.phase === 'cancel') {
            restore(true);
        } else {
            restore(true);
            const dialog = visibleDialogs().at(-1);
            if (dialog) {
                const active = document.activeElement instanceof HTMLElement ? document.activeElement : null;
                // Select-only comboboxes retain focus on their trigger, outside the listbox portal.
                const controlsDialog = Boolean(active && dialog.id
                    && active.getAttribute('aria-controls')?.split(/\s+/).includes(dialog.id));
                const focused = active && (dialog.contains(active) || controlsDialog) ? active : dialog;
                focused.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', bubbles: true, cancelable: true }));
            } else if (hasAndroidBackDestination(window.history.state?.appHistoryIndex, 0)) {
                window.history.back();
            }
            requestAnimationFrame(sync);
        }
    });
    // App navigation and collection suites already share browser history; observe their writes.
    const push = window.history.pushState.bind(window.history);
    const replace = window.history.replaceState.bind(window.history);
    window.history.pushState = (...args) => { push(...args); sync(); };
    window.history.replaceState = (...args) => { replace(...args); sync(); };
    window.addEventListener('popstate', sync);
    let syncFrame = 0;
    const observer = new MutationObserver(records => {
        const selector = '[role="dialog"], [role="menu"], [role="listbox"]';
        const touchesOverlay = records.some(record => record.type === 'attributes'
            || [...record.addedNodes, ...record.removedNodes].some(node => node instanceof HTMLElement
                && (node.matches(selector) || node.querySelector(selector))));
        if (!touchesOverlay || syncFrame) return;
        syncFrame = requestAnimationFrame(() => { syncFrame = 0; sync(); });
    });
    observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['role', 'aria-hidden'] });
    sync();
};

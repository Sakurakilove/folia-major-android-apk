// Reuse desktop app-region declarations for Android floating-window movement.
interface WindowDragPlugin {
    windowDrag(options: { phase: 'start' | 'move' | 'end'; x: number; y: number }): Promise<{ active: boolean }>;
}

const isDragRegion = (target: EventTarget | null): boolean => {
    if (target instanceof Element && target.closest('button, a, input, textarea, select, [role=button], [role=slider], [contenteditable=true]')) return false;
    for (let element = target instanceof Element ? target : null; element; element = element.parentElement) {
        const style = getComputedStyle(element);
        const region = (style.getPropertyValue('--folia-app-region') || style.getPropertyValue('-webkit-app-region')).trim();
        if (region === 'no-drag') return false;
        if (region === 'drag') return true;
    }
    return false;
};

export const installAndroidWindowDrag = (runtime: WindowDragPlugin): void => {
    let pointer: number | null = null;
    let active = false;
    let frame = 0;
    let latest: { x: number; y: number } | null = null;
    let sending = false;
    const flush = () => {
        frame = 0;
        if (!active || sending || !latest) return;
        const position = latest; latest = null; sending = true;
        void runtime.windowDrag({ phase: 'move', ...position }).catch(error => {
            active = false; console.warn('[AndroidWindow] Cannot move floating window', error);
        }).finally(() => { sending = false; if (active && latest) frame = requestAnimationFrame(flush); });
    };
    window.addEventListener('pointerdown', event => {
        if (pointer !== null || event.button !== 0 || !isDragRegion(event.target)) return;
        const id = event.pointerId;
        pointer = id;
        void runtime.windowDrag({ phase: 'start', x: event.screenX, y: event.screenY }).then(result => {
            if (pointer === id) {
                active = result.active;
                if (active && event.target instanceof Element) {
                    try { event.target.setPointerCapture(id); } catch { /* The pointer may have ended during native dispatch. */ }
                }
                if (active && latest && !frame) frame = requestAnimationFrame(flush);
            }
        }).catch(error => { active = false; console.warn('[AndroidWindow] Cannot begin floating-window drag', error); });
    }, true);
    window.addEventListener('pointermove', event => {
        if (event.pointerId !== pointer) return;
        latest = { x: event.screenX, y: event.screenY };
        if (active && !frame) frame = requestAnimationFrame(flush);
    }, true);
    const finish = (event: PointerEvent) => {
        if (event.pointerId !== pointer) return;
        pointer = null; active = false; latest = null; cancelAnimationFrame(frame); frame = 0;
        void runtime.windowDrag({ phase: 'end', x: event.screenX, y: event.screenY })
            .catch(error => console.warn('[AndroidWindow] Cannot finish floating-window drag', error));
    };
    window.addEventListener('pointerup', finish, true);
    window.addEventListener('pointercancel', finish, true);
};

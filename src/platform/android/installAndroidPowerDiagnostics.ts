import { registerPlugin } from '@capacitor/core';

// Two bounded snapshots per foreground session; no permanent sampling or animation-frame poller.
type PowerSnapshot = {
    elapsedMs: number;
    hostCpuMs: number;
    wholeDeviceWattsEstimate?: number;
    [key: string]: unknown;
};
const native = registerPlugin<{ powerSnapshot(): Promise<PowerSnapshot> }>('FoliaRuntime');
let installed = false;

export const installAndroidPowerDiagnostics = (): void => {
    if (installed || new URLSearchParams(location.search).get('foliaAndroidHost') === 'wallpaper') return;
    installed = true;
    let timer = 0;
    let generation = 0;
    let lastStarted = -Infinity;
    const sample = async () => {
        timer = 0;
        if (document.hidden || performance.now() - lastStarted < 40000) return;
        const epoch = generation;
        try {
            const first = await native.powerSnapshot();
            if (document.hidden || epoch !== generation) return;
            timer = window.setTimeout(() => {
                timer = 0;
                void native.powerSnapshot().then(second => {
                    if (document.hidden || epoch !== generation) return;
                    lastStarted = performance.now();
                    const elapsed = second.elapsedMs - first.elapsedMs;
                    console.info('[AndroidPower] Bounded native sample', {
                        ...second,
                        hostCpuCoreEquivalents: elapsed > 0 ? (second.hostCpuMs - first.hostCpuMs) / elapsed : null,
                        playerView: document.documentElement.dataset.foliaPlayerView,
                        nativeOptics: document.documentElement.dataset.foliaNativeOptics,
                        viewportPixels: Math.round(innerWidth * innerHeight * devicePixelRatio ** 2),
                    });
                }).catch(error => console.warn('[AndroidPower] Cannot finish native sample', error));
            }, 8000);
        } catch (error) { console.warn('[AndroidPower] Cannot start native sample', error); }
    };
    const visible = () => {
        generation++;
        clearTimeout(timer);
        timer = 0;
        if (!document.hidden) timer = window.setTimeout(() => { void sample(); }, 2500);
    };
    document.addEventListener('visibilitychange', visible);
    window.addEventListener('folia-player-view-changed', visible);
    window.addEventListener('pagehide', () => { generation++; clearTimeout(timer); timer = 0; });
    window.addEventListener('pageshow', visible);
    visible();
};

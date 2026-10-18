import { Capacitor } from '@capacitor/core';
import { setAndroidFrameActivity, VISUALIZER_FRAME_RATE_STORAGE_KEY } from '../../utils/frameRateLimiter';
import './androidPhone.css';

// Android rendering rests in the background; stationary library screens use 20 FPS even during music; gestures and the player use the chosen cap.
export const installAndroidPresentation = (): void => {
    if (!Capacitor.isNativePlatform() || Capacitor.getPlatform() !== 'android') return;
    const root = document.documentElement;
    root.dataset.foliaAndroid = 'true';
    // Respect an explicit user choice, including an unlimited frame rate.
    if (localStorage.getItem(VISUALIZER_FRAME_RATE_STORAGE_KEY) === null) localStorage.setItem(VISUALIZER_FRAME_RATE_STORAGE_KEY, '60');
    let nativeVisible = true;
    let firstScreenReady = false;
    let interacting = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const sync = () => {
        const playing = Array.from(document.querySelectorAll('audio')).some(audio => !audio.paused && !audio.ended);
        root.dataset.foliaPlaying = String(playing);
        // Startup and permission-dialog lifecycle events must never freeze a visible first screen.
        // Chromium already suspends native RAF in a hidden WebView; do not park the app-wide queue.
        const suspended = firstScreenReady && document.hidden && !nativeVisible;
        root.dataset.foliaRenderPaused = String(suspended);
        setAndroidFrameActivity(false, firstScreenReady && root.dataset.foliaPlayerView !== 'true' && !interacting);
    };
    const interact = () => {
        const changed = !interacting;
        interacting = true;
        clearTimeout(timer);
        if (changed) sync();
        timer = setTimeout(() => { interacting = false; sync(); }, 1500);
    };
    window.addEventListener('folia-first-screen-mounted', () => { firstScreenReady = true; sync(); });
    document.addEventListener('visibilitychange', sync);
    for (const event of ['play', 'pause', 'ended', 'emptied']) document.addEventListener(event, sync, true);
    document.addEventListener('pointerdown', interact, { passive: true });
    document.addEventListener('pointermove', event => { if (event.buttons !== 0) interact(); }, { passive: true });
    document.addEventListener('keydown', interact);
    window.addEventListener('folia-player-view-changed', sync);
    window.addEventListener('folia-android-visibility', event => {
        nativeVisible = (event as CustomEvent<boolean>).detail;
        sync();
    });
    sync();
};

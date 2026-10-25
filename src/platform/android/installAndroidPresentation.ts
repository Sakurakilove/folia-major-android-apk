import { Capacitor } from '@capacitor/core';
import { setAndroidFrameActivity, VISUALIZER_FRAME_RATE_STORAGE_KEY } from '../../utils/frameRateLimiter';
import './androidPhone.css';
import { installAndroidPlaybackDiagnostics } from './installAndroidPlaybackDiagnostics';

// Explicit host visibility can suspend wallpaper rendering; visible animations keep the user-selected cadence.
export const installAndroidPresentation = (): void => {
    const wallpaperHost = new URLSearchParams(window.location?.search ?? '').get('foliaAndroidHost') === 'wallpaper';
    if (!wallpaperHost && (!Capacitor.isNativePlatform() || Capacitor.getPlatform() !== 'android')) return;
    installAndroidPlaybackDiagnostics();
    const root = document.documentElement;
    root.dataset.foliaAndroid = 'true';
    // Respect an explicit user choice, including an unlimited frame rate.
    if (localStorage.getItem(VISUALIZER_FRAME_RATE_STORAGE_KEY) === null) localStorage.setItem(VISUALIZER_FRAME_RATE_STORAGE_KEY, '60');
    let nativeVisible = true;
    let firstScreenReady = false;
    const sync = () => {
        const playing = Array.from(document.querySelectorAll('audio')).some(audio => !audio.paused && !audio.ended);
        root.dataset.foliaPlaying = String(playing);
        // Startup and permission-dialog lifecycle events must never freeze a visible first screen.
        // Chromium already suspends native RAF in a hidden WebView; do not park the app-wide queue.
        const suspended = wallpaperHost ? !nativeVisible : firstScreenReady && document.hidden && !nativeVisible;
        root.dataset.foliaRenderPaused = String(suspended);
        setAndroidFrameActivity(wallpaperHost && !nativeVisible);
    };
    window.addEventListener('folia-first-screen-mounted', () => { firstScreenReady = true; sync(); });
    document.addEventListener('visibilitychange', sync);
    for (const event of ['play', 'pause', 'ended', 'emptied']) document.addEventListener(event, sync, true);
    window.addEventListener('folia-player-view-changed', sync);
    window.addEventListener('folia-android-visibility', event => {
        nativeVisible = (event as CustomEvent<boolean>).detail;
        sync();
    });
    sync();
};

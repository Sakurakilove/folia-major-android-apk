import { afterEach, describe, expect, it, vi } from 'vitest';
const activity = vi.hoisted(() => vi.fn());
vi.mock('@capacitor/core', () => ({ Capacitor: { isNativePlatform: () => true, getPlatform: () => 'android' } }));
vi.mock('../../../src/utils/frameRateLimiter', () => ({ setAndroidFrameActivity: activity, VISUALIZER_FRAME_RATE_STORAGE_KEY: 'visualizer_frame_rate' }));
import { installAndroidPresentation } from '../../../src/platform/android/installAndroidPresentation';

// A stale Activity pause from a startup permission dialog must not freeze the visible app.
afterEach(() => { vi.unstubAllGlobals(); vi.clearAllMocks(); });
describe('Android first-screen visibility', () => {
    it('never parks the global RAF queue and defers idle throttling until the first screen mounts', () => {
        const root = { dataset: {} as Record<string, string> };
        const document = Object.assign(new EventTarget(), { documentElement: root, hidden: true, querySelectorAll: () => [] });
        const window = new EventTarget();
        vi.stubGlobal('window', window);
        vi.stubGlobal('document', document);
        vi.stubGlobal('localStorage', { getItem: () => '60', setItem: vi.fn() });
        installAndroidPresentation();
        expect(activity).toHaveBeenLastCalledWith(false, false);
        expect(root.dataset.foliaRenderPaused).toBe('false');
        document.hidden = false;
        window.dispatchEvent(new Event('folia-first-screen-mounted'));
        window.dispatchEvent(new CustomEvent('folia-android-visibility', { detail: false }));
        expect(activity).toHaveBeenLastCalledWith(false, true);
        expect(root.dataset.foliaRenderPaused).toBe('false');
        root.dataset.foliaPlayerView = 'true';
        window.dispatchEvent(new Event('folia-player-view-changed'));
        expect(activity).toHaveBeenLastCalledWith(false, false);
        root.dataset.foliaPlayerView = 'false';
        document.querySelectorAll = () => [{ paused: false, ended: false }] as never;
        window.dispatchEvent(new Event('folia-player-view-changed'));
        expect(activity).toHaveBeenLastCalledWith(false, true);
        document.hidden = true;
        document.dispatchEvent(new Event('visibilitychange'));
        expect(root.dataset.foliaRenderPaused).toBe('true');
        window.dispatchEvent(new CustomEvent('folia-android-visibility', { detail: true }));
        expect(root.dataset.foliaRenderPaused).toBe('false');
    });
});

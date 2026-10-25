import { Capacitor, registerPlugin } from '@capacitor/core';
import { installAndroidMediaSession } from './installAndroidMediaSession';
import { installAndroidBack } from './installAndroidBack';
import { installAndroidWindowDrag } from './installAndroidWindowDrag';
import { installAndroidFileSystem, getAndroidFileUri } from './androidFileSystem';
import { createAndroidWire, type BinaryPlugin } from './androidWire';
import { installAndroidEvents } from './androidEvents';
import type { PluginListenerHandle } from '@capacitor/core';

// Adapt the desktop contracts that have actual Android implementations.
interface RuntimePlugin extends BinaryPlugin {
    start(): Promise<{ ready: boolean; windowId: number }>;
    invoke(options: { method: string; args: unknown[] }): Promise<{ result: unknown }>;
    screen(options: { keepAwake: boolean }): Promise<{ active: boolean }>;
    minimize(): Promise<void>;
    localFonts(): Promise<{fonts: Array<{family: string}>}>;
    windowDrag(options: { phase: 'start' | 'move' | 'end'; x: number; y: number }): Promise<{ active: boolean }>;
    shell(options: { method: string; args: unknown[] }): Promise<{ result: unknown }>;
    playback(options: { playing: boolean; title: string; artist: string; position: number; duration: number }): Promise<void>;
    addListener(event: 'appVisibility', listener: (event: { visible: boolean }) => void): Promise<PluginListenerHandle>;
    addListener(event: 'mediaAction', listener: (event: { action: MediaSessionAction; position: number }) => void): Promise<PluginListenerHandle>;
    addListener(event: 'backGesture', listener: (event: { phase: 'start' | 'progress' | 'cancel' | 'commit'; progress: number; nativeViewport?: boolean; edge?: number }) => void): Promise<PluginListenerHandle>;
    taskbarControls(options: { hasActiveTrack: boolean; canGoPrevious: boolean; canGoNext: boolean; isPlaying: boolean }): Promise<{ active: boolean }>;
    addListener(event: 'taskbarControl', listener: (event: { action: 'previous' | 'play-pause' | 'next' }) => void): Promise<PluginListenerHandle>;
    voiceInput(options: { enabled?: boolean }): Promise<{ active: boolean; enabled: boolean; supported: boolean }>;
    addListener(event: 'voiceInputState', listener: (event: { active: boolean; enabled: boolean; supported: boolean }) => void): Promise<PluginListenerHandle>;
    backState(options: { enabled: boolean; nativeViewport?: boolean }): Promise<void>;
}

let installation: Promise<void> | null = null;
const installBridge = async (): Promise<void> => {
    if (!Capacitor.isNativePlatform() || Capacitor.getPlatform() !== 'android') return;
    if (window.electron?.platform === 'android') return;
    const runtime = registerPlugin<RuntimePlugin>('FoliaRuntime');
    const { windowId } = await runtime.start();
    Object.assign(window, { __foliaAndroidWindowId: windowId });
    const wire = createAndroidWire(runtime);
    const invoke = async (method: string, ...args: unknown[]) => wire.decode((await runtime.invoke({ method, args: await wire.encode(args) as unknown[] })).result);
    await invoke('_androidRendererReady');
    const methods = ['getSettings', 'saveSettings', 'getNeteasePort', 'getNeteaseApiStatus', 'restartNeteaseApi',
        'getLoginDiagnostics', 'getQqPort', 'getQqApiStatus', 'getKugouApiStatus', 'kugouRequest', 'bodianRequest',
        'getCacheDirectory', 'resetCacheDirectory', 'setAppLocale', 'generateTheme', 'segmentLyrics',
        'testAiConnection', 'fetchLyricProxy', 'installAndroidModZip', 'debugRendererMemory'];
    const bridge: Record<string, unknown> = { platform: 'android', isLinuxX11: false };
    bridge.webUtils = { getPathForFile: getAndroidFileUri };
    for (const method of methods) bridge[method] = (...args: unknown[]) => invoke(method, ...args);
    installAndroidEvents(bridge, invoke, await invoke('_capabilities') as string[], windowId);
    bridge.openExternalUrl = async (url: string) => {
        const parsed = new URL(url);
        if (!['https:', 'http:'].includes(parsed.protocol)) throw new Error('Unsupported URL scheme');
        await runtime.shell({ method: 'openExternal', args: [url] });
        return true;
    };
    bridge.setPlaybackDisplaySleepBlockingActive = async (active: boolean) => (await runtime.screen({ keepAwake: active })).active;
    if (windowId === 1) {
        bridge.updateTaskbarControls = async (options: { hasActiveTrack: boolean; canGoPrevious: boolean; canGoNext: boolean; isPlaying: boolean }) => (await runtime.taskbarControls(options)).active;
        bridge.onTaskbarControl = (callback: (action: 'previous' | 'play-pause' | 'next') => void) => {
            const listener = runtime.addListener('taskbarControl', event => callback(event.action));
            return () => { void listener.then(handle => handle.remove()); };
        };
        bridge.getVoiceInputPauseStatus = () => runtime.voiceInput({});
        const originalSave = bridge.saveSettings as (key: string, value: unknown) => Promise<unknown>;
        bridge.saveSettings = async (key: string, value: unknown) => {
            const result = await originalSave(key, value);
            if (key === 'VOICE_INPUT_PAUSE_ENABLED') await runtime.voiceInput({ enabled: (result as Record<string,unknown>).VOICE_INPUT_PAUSE_ENABLED === true });
            return result;
        };
        const settings = await invoke('getSettings') as Record<string, unknown>;
        await runtime.shell({ method: 'hideTaskbar', args: [settings.HIDE_TASKBAR_ICON === true] });
        const wallpaper = await runtime.shell({ method: 'wallpaperStatus', args: [] });
        await invoke('_syncWallpaperState', wallpaper.result);
        await runtime.voiceInput({ enabled: settings.VOICE_INPUT_PAUSE_ENABLED === true });
        await invoke('_restoreNativeWindowEffects');
        if (settings.MAIN_WINDOW_ALWAYS_ON_TOP === true || settings.TRANSPARENT_PLAYER_BACKGROUND === true) {
            try {
                await invoke('setMainWindowAlwaysOnTop', true);
                if (settings.TRANSPARENT_PLAYER_BACKGROUND === true) await invoke('setWindowTransparentMode', true);
            } catch (error) { console.warn('[AndroidWindow] Cannot restore floating window', error); }
        }
        bridge.onVoiceInputStateChanged = (callback: (event: unknown) => void) => {
            const listener = runtime.addListener('voiceInputState', callback);
            return () => { void listener.then(handle => handle.remove()); };
        };
    }
    if (windowId !== 1) {
        const pointer = (inside: boolean) => { void invoke('_androidPointerState', inside).catch(error => console.warn('[AndroidWindow] Pointer state failed', error)); };
        window.addEventListener('pointerenter', () => pointer(true));
        window.addEventListener('pointerleave', () => pointer(false));
        window.addEventListener('pointerdown', () => pointer(true));
        window.addEventListener('pointerup', event => { if (event.pointerType !== 'mouse') pointer(false); });
    }
    window.electron = bridge as unknown as Window['electron'];
    if (windowId === 1) {
        installAndroidMediaSession(runtime); installAndroidBack(runtime);
        await runtime.addListener('appVisibility', event => window.dispatchEvent(new CustomEvent('folia-android-visibility', { detail: event.visible })));
    }
    Object.assign(window,{queryLocalFonts: async () => (await runtime.localFonts()).fonts});
    installAndroidFileSystem();
    installAndroidWindowDrag(runtime);
    if ('serviceWorker' in navigator) {
        void navigator.serviceWorker.register('/folia-android-cover-sw.js', { scope: '/' })
            .catch(error => console.warn('[AndroidRuntime] Local cover route unavailable', error));
    }
};

export const installAndroidBridge = (): Promise<void> => {
    if (!installation) installation = installBridge().catch(error => { installation = null; throw error; });
    return installation;
};

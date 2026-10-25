import type { PluginListenerHandle } from '@capacitor/core';
import { getMediaSessionAudio } from '../../utils/mediaSessionSync';

// Forward the existing media-session actions to Android's lock screen, without replacing playback logic.
interface AndroidMediaPlugin {
    playback(options: { playing: boolean; title: string; artist: string; position: number; duration: number }): Promise<void>;
    addListener(event: 'mediaAction', listener: (event: { action: MediaSessionAction; position: number }) => void): Promise<PluginListenerHandle>;
}

export const installAndroidMediaSession = (runtime: AndroidMediaPlugin): void => {
    const session = navigator.mediaSession;
    const handlers = new Map<MediaSessionAction, MediaSessionActionHandler>();
    if (session) {
        const original = session.setActionHandler.bind(session);
        session.setActionHandler = (action, handler) => {
            if (handler) handlers.set(action, handler);
            else handlers.delete(action);
            original(action, handler);
        };
    }
    void runtime.addListener('mediaAction', event => {
        const handler = handlers.get(event.action);
        if (handler) handler({ action: event.action, seekTime: event.position });
    });
    let last = '';
    let hadPlayback = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const sync = () => {
        clearTimeout(timer);
        const audio = getMediaSessionAudio();
        if (!audio && !hadPlayback) return;
        const playing = Boolean(audio && !audio.paused && !audio.ended);
        if (!playing && !hadPlayback) return;
        hadPlayback ||= playing;
        if (playing) timer = setTimeout(sync, 10000);
        const metadata = session?.metadata;
        const snapshot = { playing, title: metadata?.title || 'Folia', artist: metadata?.artist || '',
            position: audio && Number.isFinite(audio.currentTime) ? audio.currentTime : 0,
            duration: audio && Number.isFinite(audio.duration) ? audio.duration : 0 };
        const key = JSON.stringify({ ...snapshot, position: Math.floor(snapshot.position / 10) });
        if (key === last) return;
        void runtime.playback(snapshot).then(() => { last = key; }).catch(error => console.warn('[AndroidMedia] Cannot update media controls', error));
    };
    document.addEventListener('play', sync, true);
    document.addEventListener('pause', sync, true);
    document.addEventListener('ended', sync, true);
    document.addEventListener('seeked', sync, true);
    document.addEventListener('loadedmetadata', sync, true);
    document.addEventListener('durationchange', sync, true);
};

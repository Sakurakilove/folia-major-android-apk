// Record exceptional playback/render events locally; no frame polling or media URLs enter the log.
let installed = false;
export const installAndroidPlaybackDiagnostics = (): void => {
    if (installed) return;
    installed = true;
    for (const kind of ['waiting', 'stalled', 'error']) {
        document.addEventListener(kind, event => {
            const audio = event.target;
            if (!(audio instanceof HTMLAudioElement) || !audio.hasAttribute('data-folia-playback-deck')) return;
            let ahead = 0;
            for (let index = 0; index < audio.buffered.length; index++) {
                if (audio.buffered.start(index) <= audio.currentTime && audio.buffered.end(index) >= audio.currentTime) ahead = audio.buffered.end(index) - audio.currentTime;
            }
            console.warn('[AndroidAudio] Media pipeline event', {
                kind, deck: audio.dataset.foliaPlaybackDeck, position: audio.currentTime,
                bufferedAhead: ahead, readyState: audio.readyState, networkState: audio.networkState,
                paused: audio.paused, code: audio.error?.code ?? null,
            });
        }, true);
    }
    document.addEventListener('webglcontextlost', event => {
        const canvas = event.target;
        if (!(canvas instanceof HTMLCanvasElement)) return;
        console.warn('[AndroidRenderer] WebGL context lost', { width: canvas.width, height: canvas.height });
    }, true);
};

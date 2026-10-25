import { generateEffectSamples, type EffectSampleKind } from '../services/audioEffects/sourceSamples';

// Return owned PCM arrays; no AudioContext or UI work runs in this worker.
self.onmessage = (event: MessageEvent<{ id: number; kind: EffectSampleKind; sampleRate: number }>) => {
    const { id, kind, sampleRate } = event.data;
    try {
        const channels = generateEffectSamples(kind, sampleRate);
        self.postMessage({ id, channels }, { transfer: channels.map(channel => channel.buffer as ArrayBuffer) });
    } catch (error) {
        self.postMessage({ id, error: String(error) });
    }
};

import { effectSampleChunks, type EffectSampleKind } from './sourceSamples';

// One preparation per context and kind, with a yielding fallback if a worker cannot start.
let worker: Worker | null = null;
let nextId = 0;
const pending = new Map<number, { resolve: (data: Float32Array[]) => void; reject: (error: Error) => void; timer: ReturnType<typeof setTimeout> }>();
const cache = new WeakMap<BaseAudioContext, Map<EffectSampleKind, Promise<AudioBuffer>>>();
const failWorker = () => {
    worker?.terminate(); worker = null;
    for (const entry of pending.values()) { clearTimeout(entry.timer); entry.reject(new Error('Audio sample worker unavailable')); }
    pending.clear();
};
const requestSamples = (kind: EffectSampleKind, sampleRate: number): Promise<Float32Array[]> => new Promise((resolve, reject) => {
    if (!worker) {
        try {
            worker = new Worker(new URL('../../workers/audioEffectSamples.worker.ts', import.meta.url), { type: 'module' });
            const owner = worker;
            worker.onmessage = event => {
                if (worker !== owner) return;
                const entry = pending.get(event.data.id);
                if (!entry) return;
                pending.delete(event.data.id); clearTimeout(entry.timer);
                if (event.data.error) entry.reject(new Error(event.data.error));
                else entry.resolve(event.data.channels);
            };
            worker.onerror = event => { event.preventDefault(); if (worker === owner) failWorker(); };
            worker.onmessageerror = () => { if (worker === owner) failWorker(); };
        } catch (error) { reject(error); return; }
    }
    const id = ++nextId;
    pending.set(id, { resolve, reject, timer: setTimeout(() => { if (pending.has(id)) failWorker(); }, 30000) });
    try { worker.postMessage({ id, kind, sampleRate }); }
    catch (error) { failWorker(); }
});
const yieldSamples = async (kind: EffectSampleKind, sampleRate: number): Promise<Float32Array[]> => {
    const chunks = effectSampleChunks(kind, sampleRate);
    let next = chunks.next();
    while (!next.done) {
        await new Promise<void>(resolve => setTimeout(resolve, 0));
        next = chunks.next();
    }
    return next.value;
};
export const prepareEffectBuffer = (context: BaseAudioContext, kind: EffectSampleKind): Promise<AudioBuffer> => {
    let entries = cache.get(context);
    if (!entries) { entries = new Map(); cache.set(context, entries); }
    const existing = entries.get(kind);
    if (existing) return existing;
    const result = requestSamples(kind, context.sampleRate).catch(() => yieldSamples(kind, context.sampleRate)).then(channels => {
        const buffer = context.createBuffer(channels.length, channels[0].length, context.sampleRate);
        channels.forEach((channel, index) => buffer.getChannelData(index).set(channel));
        return buffer;
    }).catch(error => { entries!.delete(kind); throw error; });
    entries.set(kind, result);
    return result;
};

// Shared sample generation; chunk boundaries let the fallback yield without changing precision.
export type EffectSampleKind = 'noise' | 'reverb';
export function* effectSampleChunks(kind: EffectSampleKind, sampleRate: number, seconds = 2.2, decay = 2.8): Generator<void, Float32Array[]> {
    const length = Math.max(1, Math.floor(sampleRate * (kind === 'noise' ? 3 : seconds)));
    const channels = [new Float32Array(length), new Float32Array(length)];
    for (const data of channels) {
        let crackle = 0;
        for (let index = 0; index < length; index++) {
            if (kind === 'noise') {
                if (Math.random() < 0.0007) crackle = Math.random() * 2 - 1;
                crackle *= 0.88;
                data[index] = (Math.random() * 2 - 1) * 0.12 + crackle * 0.9;
            } else {
                data[index] = (Math.random() * 2 - 1) * (1 - index / length) ** decay;
            }
            if ((index + 1) % 8192 === 0) yield;
        }
    }
    return channels;
}
export const generateEffectSamples = (kind: EffectSampleKind, sampleRate: number, seconds?: number, decay?: number): Float32Array[] => {
    const chunks = effectSampleChunks(kind, sampleRate, seconds, decay);
    let next = chunks.next();
    while (!next.done) next = chunks.next();
    return next.value;
};

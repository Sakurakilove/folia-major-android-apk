import { rampParam } from './effectParams';
import { createVinylNoiseBuffer } from './effectSources';
import { createReleaseTimer, type AudioEffectBranch } from './effectBranchRelease';
import type { AudioEffectNodes } from './effectNodes';
import { prepareEffectBuffer } from './preparedBuffers';

// src/services/audioEffects/noiseBranch.ts
// Looping vinyl noise floor mixed straight into the chain output.

// Crackles and hiss are band-passed so the noise sits with the music instead of on top of it.
export const createNoiseBranch = (context: AudioContext, nodes: AudioEffectNodes): AudioEffectBranch => {
    let source: AudioBufferSourceNode | null = null;
    let filter: BiquadFilterNode | null = null;
    const release = createReleaseTimer();
    let prepared: AudioBuffer | null = null;
    let preparing = false;
    let desired = 0;
    let disposed = false;

    const teardown = () => {
        if (source) {
            try {
                source.stop();
            } catch {
                // Already stopped together with the audio context.
            }
            source.disconnect();
            source = null;
        }
        filter?.disconnect();
        filter = null;
    };

    const set = (amount: number) => {
        desired = amount;
        if (amount > 0) {
            release.cancel();
            if (!source) {
                if (!prepared) {
                    if (typeof (context as AudioContext & { startRendering?: unknown }).startRendering === 'function') {
                        prepared = createVinylNoiseBuffer(context);
                    } else {
                        if (!preparing) {
                            preparing = true;
                            void prepareEffectBuffer(context, 'noise').then(buffer => {
                                preparing = false;
                                if (disposed) return;
                                prepared = buffer;
                                if (desired > 0) set(desired);
                            }).catch(error => {
                                preparing = false;
                                console.warn('[AudioEffects] Cannot prepare noise:', error);
                            });
                        }
                        return;
                    }
                }
                filter = context.createBiquadFilter();
                filter.type = 'bandpass';
                filter.frequency.value = 2600;
                filter.Q.value = 0.5;
                source = context.createBufferSource();
                source.buffer = prepared;
                source.loop = true;
                source.connect(filter);
                filter.connect(nodes.noiseGain);
                source.start();
            }
            rampParam(context, nodes.noiseGain.gain, amount ** 1.4 * 0.55, 0.12);
            return;
        }

        rampParam(context, nodes.noiseGain.gain, 0, 0.12);
        if (source) {
            release.schedule(teardown);
        }
    };

    return {
        set,
        dispose: () => {
            disposed = true;
            desired = 0;
            release.cancel();
            teardown();
        },
    };
};

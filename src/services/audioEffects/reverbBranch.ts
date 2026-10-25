import { rampParam } from './effectParams';
import { createReverbImpulse } from './effectSources';
import { createReleaseTimer, type AudioEffectBranch } from './effectBranchRelease';
import type { AudioEffectNodes } from './effectNodes';
import { prepareEffectBuffer } from './preparedBuffers';

// src/services/audioEffects/reverbBranch.ts
// Parallel convolution reverb; the impulse response is generated once and released after the wet fade.

// The dry leg is trimmed slightly as the wet leg comes up so the total level stays steady.
export const createReverbBranch = (context: AudioContext, nodes: AudioEffectNodes): AudioEffectBranch => {
    let convolver: ConvolverNode | null = null;
    const release = createReleaseTimer();
    let prepared: AudioBuffer | null = null;
    let preparing = false;
    let desired = 0;
    let disposed = false;

    const teardown = () => {
        if (!convolver) return;
        nodes.wetSend.disconnect(convolver);
        convolver.disconnect();
        convolver = null;
    };

    const set = (amount: number) => {
        desired = amount;
        if (amount > 0) {
            release.cancel();
            if (!convolver) {
                if (!prepared) {
                    if (typeof (context as AudioContext & { startRendering?: unknown }).startRendering === 'function') {
                        prepared = createReverbImpulse(context);
                    } else {
                        if (!preparing) {
                            preparing = true;
                            void prepareEffectBuffer(context, 'reverb').then(buffer => {
                                preparing = false;
                                if (disposed) return;
                                prepared = buffer;
                                if (desired > 0) set(desired);
                            }).catch(error => {
                                preparing = false;
                                console.warn('[AudioEffects] Cannot prepare reverb:', error);
                            });
                        }
                        return;
                    }
                }
                convolver = context.createConvolver();
                convolver.normalize = true;
                convolver.buffer = prepared;
                nodes.wetSend.connect(convolver);
                convolver.connect(nodes.wet);
            }
            rampParam(context, nodes.wet.gain, amount * 0.75, 0.08);
            rampParam(context, nodes.dry.gain, 1 - amount * 0.2, 0.08);
            return;
        }

        rampParam(context, nodes.wet.gain, 0, 0.08);
        rampParam(context, nodes.dry.gain, 1, 0.08);
        if (convolver) {
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

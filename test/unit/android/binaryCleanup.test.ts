import { afterEach, describe, expect, it, vi } from 'vitest';
import { createAndroidWire, type BinaryPlugin } from '../../../src/platform/android/androidWire';

// Interrupted native transfers must release their private files rather than accumulate audio buffers.
afterEach(() => vi.unstubAllGlobals());
const native = (): BinaryPlugin => ({
    binaryStart: vi.fn(async () => ({ token: 'owned-upload' })),
    binaryAppend: vi.fn(async () => {}),
    binaryFinish: vi.fn(async () => ({ path: '/private/upload.bin' })),
    binaryAbort: vi.fn(async () => {}),
    binaryRelease: vi.fn(async () => {}),
});
describe('Android binary transfer cleanup', () => {
    it('aborts an interrupted upload and preserves the original transfer failure', async () => {
        const bridge = native();
        vi.mocked(bridge.binaryAppend).mockRejectedValueOnce(new Error('Transfer interrupted'));
        await expect(createAndroidWire(bridge).encode(new Float32Array([0.5, -0.5]))).rejects.toThrow('Transfer interrupted');
        expect(bridge.binaryAbort).toHaveBeenCalledWith({ token: 'owned-upload' });
        expect(bridge.binaryFinish).not.toHaveBeenCalled();
    });
    it('releases a native result even when fetching its body fails', async () => {
        const bridge = native();
        vi.stubGlobal('fetch', vi.fn(async () => ({ ok: true, arrayBuffer: async () => { throw new Error('Reader closed'); } })));
        await expect(createAndroidWire(bridge).decode({ __foliaBinary: true, path: '/private/result.bin', type: 'Float32Array' })).rejects.toThrow('Reader closed');
        expect(bridge.binaryRelease).toHaveBeenCalledWith({ path: '/private/result.bin' });
    });
});

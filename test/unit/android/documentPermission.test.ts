import { describe, expect, it, vi } from 'vitest';
const native = vi.hoisted(() => ({ queryDocumentPermission: vi.fn(), requestDocumentPermission: vi.fn() }));
vi.mock('@capacitor/core', () => ({ Capacitor: { isNativePlatform: () => true }, registerPlugin: () => native }));
import { reviveAndroidDirectoryHandles } from '../../../src/platform/android/androidFileSystem';

// A restored library folder must ask Android to restore its grant, not mistake stat access for write permission.
describe('Android document permission recovery', () => {
    it('keeps the restored URI and forwards read/write intent to the system permission flow', async () => {
        const saved = { library: { __foliaAndroidHandle: true, uri: 'content://documents/tree/music', kind: 'directory', name: 'Music' } };
        const handles = reviveAndroidDirectoryHandles(saved) as unknown as { library: {
            uri: string; queryPermission(options: { mode: string }): Promise<PermissionState>;
            requestPermission(options: { mode: string }): Promise<PermissionState>;
        } };
        native.queryDocumentPermission.mockResolvedValueOnce({ state: 'prompt' });
        native.requestDocumentPermission.mockResolvedValueOnce({ state: 'granted' });
        expect(await handles.library.queryPermission({ mode: 'readwrite' })).toBe('prompt');
        expect(await handles.library.requestPermission({ mode: 'readwrite' })).toBe('granted');
        expect(native.queryDocumentPermission).toHaveBeenCalledWith({ uri: saved.library.uri, mode: 'readwrite' });
        expect(native.requestDocumentPermission).toHaveBeenCalledWith({ uri: saved.library.uri, kind: 'directory', mode: 'readwrite' });
        expect(handles.library.uri).toBe(saved.library.uri);
    });
});

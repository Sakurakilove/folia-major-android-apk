import { afterEach, describe, expect, it, vi } from 'vitest';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const createUpdates = require('../../../packaging/android/runtime/updates.cjs');

// Channel switches must invalidate in-flight release responses and use the upstream lane metadata.
afterEach(() => vi.unstubAllGlobals());
const setup = (version = '0.7.20') => {
    const values = new Map<string, unknown>([['UPDATE_CHANNEL', 'realeco']]);
    const store = { get: (key: string, fallback?: unknown) => values.get(key) ?? fallback,
        set: (key: string, value: unknown) => values.set(key, value) };
    const api = createUpdates({ store, events: { emit: vi.fn() }, dataDir: '/unused',
        platform: { app: { getVersion: () => version } } });
    return { api, store };
};
describe('Android update channel discovery', () => {
    it('discovers mobile builds from the Android repository and compares numeric revisions', async () => {
        const release = (revision: number) => ({ tag_name: `v0.7.20-mobile.${revision}`, assets: [
            { name: 'Folia-universal.apk', browser_download_url: 'https://example.invalid/app.apk' },
        ] });
        const fetch = vi.fn().mockResolvedValue(Response.json([release(9), release(10)]));
        vi.stubGlobal('fetch', fetch);
        const { api } = setup('0.7.20-mobile.8');
        const status = await api.checkForUpdates();
        expect(fetch.mock.calls[0][0]).toContain('repos/Sakurakilove/folia-major-android-apk/releases?');
        expect(status.availableVersion).toBe('0.7.20-mobile.10');
    });
    it('resolves rolling Limo metadata without treating the tag name as a version', async () => {
        const fetch = vi.fn().mockResolvedValueOnce(Response.json({ tag_name: 'limo', assets: [
            { name: 'beta.yml', browser_download_url: 'https://example.invalid/beta.yml' },
        ] })).mockResolvedValueOnce(new Response('version: 0.7.21-beta.20261017\n'));
        vi.stubGlobal('fetch', fetch);
        const { api, store } = setup();
        store.set('UPDATE_CHANNEL', 'limo');
        const status = await api.checkForUpdates();
        expect(fetch.mock.calls[0][0]).toMatch(/releases\/tags\/limo$/);
        expect(status.availableVersion).toBe('0.7.21-beta.20261017');
        expect(status.status).toBe('unsupported');
        expect(status.error).toContain('does not publish an Android APK');
    });
    it('discards a release response after the user changes channels', async () => {
        let resolve!: (value: Response) => void;
        vi.stubGlobal('fetch', vi.fn(() => new Promise<Response>(done => { resolve = done; })));
        const { api, store } = setup();
        const pending = api.checkForUpdates();
        store.set('UPDATE_CHANNEL', 'cielo');
        await api._applyUpdateSetting('UPDATE_CHANNEL');
        resolve(Response.json({ tag_name: 'v99.0.0', assets: [] }));
        await pending;
        expect(api.getUpdateStatus().availableVersion).toBeNull();
        expect(api.getUpdateStatus().status).toBe('idle');
    });
    it('disables internal-channel checks and starts checking when the preference is enabled', async () => {
        const fetch = vi.fn().mockResolvedValue(Response.json({ tag_name: 'v0.7.20', assets: [] }));
        vi.stubGlobal('fetch', fetch);
        const { api, store } = setup();
        store.set('UPDATE_CHANNEL', 'internal');
        expect((await api.checkForUpdates()).updateCheckSupportReason).toBe('channel');
        expect(fetch).not.toHaveBeenCalled();
        store.set('UPDATE_CHANNEL', 'realeco'); store.set('ENABLE_UPDATE_CHECK', true);
        await api._applyUpdateSetting('ENABLE_UPDATE_CHECK');
        expect(fetch).toHaveBeenCalledTimes(1);
        expect(api.getUpdateStatus().status).toBe('latest');
    });
});

import { afterEach, describe, expect, it } from 'vitest';
import { createRequire } from 'node:module';
import { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
const require = createRequire(import.meta.url);
const temporary: string[] = [];
const directory = () => { const value = mkdtempSync(path.join(tmpdir(), 'folia-android-test-')); temporary.push(value); return value; };
afterEach(() => { for (const folder of temporary.splice(0)) rmSync(folder, { recursive: true, force: true }); });

describe('Android native runtime boundaries', () => {
    it('isolates targeted renderer events and resolves native errors without losing broadcast events', async () => {
        const events = require('../../../packaging/android/runtime/events.cjs')();
        events.emit('playback', { playing: true });
        events.target(2, 'remote-only', 'state');
        expect(events.read(0, 1).entries.map((entry: { channel: string }) => entry.channel)).toEqual(['playback']);
        expect(events.read(0, 2).entries.map((entry: { channel: string }) => entry.channel)).toEqual(['playback', 'remote-only']);
        const answer = events.native('openDialog', {});
        const rejection = expect(answer).rejects.toThrow('Permission denied');
        events.completeNative(events.nextNative().id, null, 'Permission denied');
        await rejection;
    });
    it('wakes only the target window and replays events produced before a listener reconnects', async () => {
        const events = require('../../../packaging/android/runtime/events.cjs')();
        let mainWoke = false;
        const main = events.waitEvents(0, 1).then((value: unknown) => { mainWoke = true; return value; });
        const remote = events.waitEvents(0, 2);
        events.target(2, 'remote-only', 42);
        expect((await remote).entries.map((entry: { channel: string }) => entry.channel)).toEqual(['remote-only']);
        await Promise.resolve(); expect(mainWoke).toBe(false);
        events.emit('shared-state', 'playing');
        expect((await main as { entries: Array<{ channel: string }> }).entries.map(entry => entry.channel)).toEqual(['shared-state']);
        const cursor = events.read(0, 2).cursor;
        events.target(2, 'queued', 'ready');
        expect((await events.waitEvents(cursor, 2)).entries[0].args).toEqual(['ready']);
    });
    it('feeds real Node memory and heap measurements into the original desktop monitor', async () => {
        const metrics = require('../../../packaging/android/runtime/processMetrics.cjs')();
        const runtime = process as typeof process & {
            getProcessMemoryInfo(): Promise<{ private: number; shared: number }>;
            getHeapStatistics(): { usedHeapSize: number };
            getSystemMemoryInfo(): { total: number };
        };
        const memory = await runtime.getProcessMemoryInfo();
        const heap = runtime.getHeapStatistics();
        const sample = require('../../../electron/debug/memoryMonitor.cjs').createMemoryMonitor().sample({
            metrics: metrics(), heap, system: runtime.getSystemMemoryInfo(),
            reports: new Map([[process.pid, { privateKB: memory.private, sharedKB: memory.shared, heapUsedKB: heap.usedHeapSize }]]),
        });
        expect(sample.totalWorkingSetMB).toBeGreaterThan(0);
        expect(sample.mainHeapUsedMB).toBeGreaterThan(0);
        const actualHeapMB = require('node:v8').getHeapStatistics().used_heap_size / (1024 * 1024);
        expect(Math.abs(sample.mainHeapUsedMB - actualHeapMB)).toBeLessThan(4);
        expect(sample.totalPrivateMB).toBeGreaterThan(0);
    });
    it('preserves float audio slices, consumes temporary files, and rejects paths outside the bridge directory', async () => {
        const folder = directory();
        const wire = require('../../../packaging/android/runtime/wire.cjs')(folder);
        const audio = new Float32Array([99, 0.25, -0.75, 88]).subarray(1, 3);
        const encoded = await wire.encode({ nested: [audio] });
        const file = encoded.nested[0].path;
        expect((await wire.decode(encoded)).nested[0]).toEqual(new Float32Array([0.25, -0.75]));
        expect(existsSync(file)).toBe(false);
        await expect(wire.decode({ __foliaBinary: true, path: path.join(folder, '../secret'), type: 'Uint8Array' })).rejects.toThrow('Invalid binary bridge file');
    });
    it('retains the APK-managed inference runtime when removing models and refuses to replace it', async () => {
        const folder = directory();
        const runner = path.join(folder, 'python.so'); writeFileSync(runner, 'installed-runtime');
        const { createModelStore } = require('../../../electron/analysis/modelStore.cjs');
        const models = createModelStore({ getModelsDirs: () => [folder], getDownloadDir: () => folder, builtinRuntime: runner });
        const runtime = models.status().models.find((entry: { enables: string[] }) => entry.enables.includes('runtime'))
            ?? models.status().models.find((entry: { name: string }) => entry.name.includes('runtime'));
        expect(runtime.supported).toBe(true);
        expect(runtime.path).toBe(runner);
        expect((await models.installLocal(runtime.name, runner)).ok).toBe(false);
        await models.removeAll();
        expect(readFileSync(runner, 'utf8')).toBe('installed-runtime');
    });
    it('does not evict recently saved audio and refuses to remove a replacement of a different size', async () => {
        const folder = directory();
        require('../../../packaging/android/extractDesktop.cjs');
        const cache = require('../../../packaging/android/runtime/generated/mediaCache.cjs')({ getConfiguredCacheDirectory: () => folder,
            pruneHelpers: require('../../../electron/audioCachePrune.cjs'), removeHelpers: require('../../../electron/audioCacheRemove.cjs'),
            transcodeService: { listCacheEntries: async () => [], getPinnedCacheKeys: () => [], clearCache: async () => {} },
            spotifyApiBridge: { audioFiles: { list: async () => [], clear: async () => {} } } });
        await cache.saveAudioCache('older', new Uint8Array([1, 2]), 'audio/ogg');
        await new Promise(resolve => setTimeout(resolve, 10));
        await cache.saveAudioCache('new', new Uint8Array([3, 4, 5]), 'audio/flac', 3);
        expect(await cache.hasAudioCache('older')).toBe(false);
        expect(await cache.removeAudioCache('new', 2)).toBe(false);
        expect((await cache.getAudioCache('new')).data).toEqual(Buffer.from([3, 4, 5]));
        expect(await cache.getAudioCacheStats()).toEqual({ size: 3, count: 1 });
    });
});

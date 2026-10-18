import { afterEach, describe, expect, it, vi } from 'vitest';
import { createRequire } from 'node:module';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
const require = createRequire(import.meta.url);
const createWindows = require('../../../packaging/android/runtime/windows.cjs');
const temporary: string[] = [];
afterEach(() => { vi.restoreAllMocks(); for (const directory of temporary.splice(0)) rmSync(directory, { recursive: true, force: true }); });

// The original mod export page has no preload; app control windows explicitly opt into the Android bridge.
describe('Android export window isolation', () => {
    it('reports native window refusal without an unhandled error terminating the backend', async () => {
        const warning = vi.spyOn(console, 'warn').mockImplementation(() => {});
        const Windows = createWindows({ mainWindow: {}, dataDir: '/unused', events: {
            native: async () => { throw new Error('Android refused the export display'); },
        } });
        const window = new Windows({ x: -16000 });
        await expect(window.loadFile('/unused/export.html')).rejects.toThrow('Android refused the export display');
        await new Promise(resolve => setImmediate(resolve));
        expect(warning).toHaveBeenCalled();
        expect(window.isVisible()).toBe(false);
    });
    it('loads export scripts normally and injects the desktop facade only for a trusted control window', async () => {
        const directory = mkdtempSync(path.join(tmpdir(), 'folia-export-window-')); temporary.push(directory);
        const document = '<html><head></head><body><script>window.renderReady=true</script></body></html>';
        const file = path.join(directory, 'export.html'); writeFileSync(file, document);
        const loads: string[] = [];
        const Windows = createWindows({ mainWindow: {}, dataDir: directory, events: { native: async (method: string, ...args: unknown[]) => {
            if (method === 'windowLoad') loads.push(args[1] as string);
            return true;
        } } });
        const exportWindow = new Windows({ show: false, webPreferences: { nodeIntegration: false, contextIsolation: true } });
        await exportWindow.loadFile(file);
        expect(loads[0]).toBe(document);
        const controlWindow = new Windows({ privileged: true });
        await controlWindow.loadFile(file);
        expect(loads[1]).toContain('/assets/android-secondary-bridge.js');
        expect(loads[1]).toContain('type="application/folia-deferred"');
        exportWindow.close(); controlWindow.close();
    });
});

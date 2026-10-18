import { describe, expect, it, vi } from 'vitest';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { readFileSync } from 'node:fs';
import path from 'node:path';

// Use real child processes to verify that closing the app cannot leave a model or encoder running.
describe('Android backend process lifetime', () => {
    it('ends its owned child process when the native host sends SIGTERM', async () => {
        const modulePath = path.resolve('packaging/android/runtime/lifecycle.cjs');
        const program = `require(${JSON.stringify(modulePath)})(); const child=require('node:child_process').spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{stdio:'ignore'}); console.log(child.pid); setInterval(()=>{},1000);`;
        const backend = spawn(process.execPath, ['-e', program], { stdio: ['ignore', 'pipe', 'pipe'] });
        let childPid = 0;
        try {
            backend.stdout.on('data', bytes => { const pid = Number(bytes.toString().trim()); if (Number.isInteger(pid) && pid > 0) childPid = pid; });
            await vi.waitFor(() => expect(childPid).toBeGreaterThan(0), { timeout: 5000 });
            const closed = once(backend, 'exit'); backend.kill('SIGTERM');
            expect((await closed)[0]).toBe(0);
            await vi.waitFor(() => {
                let running = false;
                try { running = !/^State:\s+Z/m.test(readFileSync(`/proc/${childPid}/status`, 'utf8')); } catch { /* The process has been reaped. */ }
                expect(running).toBe(false);
            }, { timeout: 5000 });
        } finally {
            if (backend.exitCode === null && backend.signalCode === null) backend.kill('SIGKILL');
            if (childPid) try { process.kill(childPid, 'SIGKILL'); } catch { /* Already gone. */ }
        }
    }, 15000);
});

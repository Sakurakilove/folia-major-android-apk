const fs = require('node:fs');
const crypto = require('node:crypto');

// Coalesce settings writes without blocking media requests; critical replies and shutdown flush them.
const writers = new Set();
function createJsonPersistence(file, serialize) {
    let revision = 0, committed = 0, active = null;
    const write = async () => {
        while (committed < revision) {
            const version = revision;
            const content = serialize();
            const temporary = file + '.tmp-' + crypto.randomUUID();
            try {
                await fs.promises.writeFile(temporary, content, { mode: 0o600 });
                await fs.promises.rename(temporary, file);
                committed = version;
            } finally {
                await fs.promises.rm(temporary, { force: true }).catch(() => {});
            }
        }
    };
    const start = () => {
        if (!active && committed < revision) {
            let failed = false;
            active = Promise.resolve().then(write).catch(error => { failed = true; throw error; }).finally(() => {
                active = null;
                if (!failed && committed < revision) void start();
            });
            // Most Store setters intentionally return synchronously. flush() still observes failure.
            active.catch(error => console.warn('[AndroidStore] Cannot persist settings:', error));
        }
        return active ?? Promise.resolve();
    };
    const writer = {
        schedule() { revision++; void start(); },
        async flush() {
            while (committed < revision) await start();
        },
        flushSync() {
            if (committed >= revision) return;
            const temporary = file + '.tmp-exit-' + crypto.randomUUID();
            try {
                fs.writeFileSync(temporary, serialize(), { mode: 0o600 });
                fs.renameSync(temporary, file);
                committed = revision;
            } finally {
                try { fs.rmSync(temporary, { force: true }); } catch { /* Exit is best effort. */ }
            }
        },
    };
    writers.add(writer);
    return writer;
}
async function flushJsonPersistence() {
    await Promise.all([...writers].map(writer => writer.flush()));
}
process.once('exit', () => {
    for (const writer of writers) {
        try { writer.flushSync(); }
        catch (error) { console.error('[AndroidStore] Final settings flush failed:', error); }
    }
});
module.exports = { createJsonPersistence, flushJsonPersistence };

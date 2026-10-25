const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { TrackBuffer } = require('./electron/ytm/trackBuffer.cjs');

// Android track storage keeps exact downloaded bytes on disk; readers own at most one 256 KiB chunk.
module.exports = directory => {
    const initialized = fs.mkdir(directory, { recursive: true }).then(async () => {
        // This directory is private to this single runtime; remove only abandoned track files.
        for (const name of await fs.readdir(directory)) {
            if (/^[a-f0-9-]+\.track$/.test(name)) await fs.unlink(path.join(directory, name));
        }
    });
    initialized.catch(error => console.warn('[YtmStorage] Cannot prepare track directory:', error));
    return (total, mimeType) => {
        const file = path.join(directory, crypto.randomUUID() + '.track');
        let disposed = false;
        let opening = null;
        const open = () => {
            if (disposed) return Promise.reject(new Error('Track storage was released'));
            opening ??= initialized.then(() => fs.open(file, 'wx+', 0o600));
            return opening;
        };
        return new TrackBuffer(total, mimeType, {
            async write(bytes, position) {
                const handle = await open();
                let offset = 0;
                while (offset < bytes.length) {
                    const { bytesWritten } = await handle.write(bytes, offset, bytes.length - offset, position + offset);
                    if (!bytesWritten) throw new Error('Track storage write made no progress');
                    offset += bytesWritten;
                }
            },
            async read(position, length) {
                const handle = await open();
                const bytes = Buffer.allocUnsafe(length);
                let offset = 0;
                while (offset < length) {
                    const { bytesRead } = await handle.read(bytes, offset, length - offset, position + offset);
                    if (!bytesRead) throw new Error('Track storage ended before committed bytes');
                    offset += bytesRead;
                }
                return bytes;
            },
            async close() {
                if (disposed) return;
                disposed = true;
                try { if (opening) await (await opening).close(); }
                finally { await fs.unlink(file).catch(error => { if (error.code !== 'ENOENT') throw error; }); }
            },
        });
    };
};

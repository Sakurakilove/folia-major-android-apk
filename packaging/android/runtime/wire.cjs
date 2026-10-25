const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

// Binary audio crosses the bridge through app-private files instead of giant JSON/base64 messages.
module.exports = directory => {
    fs.mkdirSync(directory, { recursive: true });
    const constructors = { Uint8Array, Uint8ClampedArray, Int8Array, Uint16Array, Int16Array, Uint32Array, Int32Array, Float32Array, Float64Array };
    const decode = async value => {
        if (!value || typeof value !== 'object') return value;
        if (value.__foliaBinary === true) {
            const file = path.resolve(value.path);
            if (path.dirname(file) !== path.resolve(directory)) throw new Error('Invalid binary bridge file');
            const bytes = await fs.promises.readFile(file);
            await fs.promises.unlink(file);
            // Large readFile buffers already own an exact ArrayBuffer; do not clone full PCM again.
            const buffer = bytes.byteOffset === 0 && bytes.byteLength === bytes.buffer.byteLength
                ? bytes.buffer : bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
            if (value.type === 'ArrayBuffer') return buffer;
            const Constructor = constructors[value.type];
            if (!Constructor || buffer.byteLength % Constructor.BYTES_PER_ELEMENT) throw new Error('Invalid binary bridge type');
            return new Constructor(buffer);
        }
        if (Array.isArray(value)) {
            const result = [];
            for (const item of value) result.push(await decode(item));
            return result;
        }
        const result = {};
        for (const [key, item] of Object.entries(value)) result[key] = await decode(item);
        return result;
    };
    const encode = async value => {
        if (value instanceof ArrayBuffer || ArrayBuffer.isView(value)) {
            const file = path.join(directory, crypto.randomUUID() + '.bin');
            const bytes = value instanceof ArrayBuffer ? Buffer.from(value) : Buffer.from(value.buffer, value.byteOffset, value.byteLength);
            await fs.promises.writeFile(file, bytes, { mode: 0o600 });
            return { __foliaBinary: true, path: file, type: value instanceof ArrayBuffer ? 'ArrayBuffer' : Buffer.isBuffer(value) ? 'Uint8Array' : value.constructor.name };
        }
        if (!value || typeof value !== 'object') return value;
        if (Array.isArray(value)) {
            const result = [];
            for (const item of value) result.push(await encode(item));
            return result;
        }
        const result = {};
        for (const [key, item] of Object.entries(value)) result[key] = await encode(item);
        return result;
    };
    return { encode, decode };
};

import { Capacitor } from '@capacitor/core';

// Chunk uploads so stem buffers and video chunks never become a single large WebView message.
export interface BinaryPlugin {
    binaryStart(): Promise<{ token: string }>;
    binaryAppend(options: { token: string; data: string }): Promise<void>;
    binaryAbort(options: { token: string }): Promise<void>;
    binaryFinish(options: { token: string }): Promise<{ path: string }>;
    binaryRelease(options: { path: string }): Promise<void>;
}

interface BinaryDescriptor { __foliaBinary: true; path: string; type: string; }
export const createAndroidWire = (native: BinaryPlugin) => {
    const encode = async (value: unknown): Promise<unknown> => {
        if (value instanceof ArrayBuffer || ArrayBuffer.isView(value)) {
            const bytes = value instanceof ArrayBuffer ? new Uint8Array(value) : new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
            const { token } = await native.binaryStart();
            try {
                for (let offset = 0; offset < bytes.length; offset += 65536) {
                    const chunk = bytes.subarray(offset, offset + 65536);
                    let text = '';
                    for (let index = 0; index < chunk.length; index++) text += String.fromCharCode(chunk[index]);
                    await native.binaryAppend({ token, data: btoa(text) });
                }
                const { path } = await native.binaryFinish({ token });
                return { __foliaBinary: true, path, type: value instanceof ArrayBuffer ? 'ArrayBuffer' : value.constructor.name };
            } catch (error) {
                await native.binaryAbort({ token }).catch(cleanupError => console.warn('[AndroidBinary] Cannot discard upload', cleanupError));
                throw error;
            }
        }
        if (!value || typeof value !== 'object') return value;
        if (Array.isArray(value)) {
            const result = [];
            for (const item of value) result.push(await encode(item));
            return result;
        }
        const result: Record<string, unknown> = {};
        for (const [key, item] of Object.entries(value)) result[key] = await encode(item);
        return result;
    };
    const decode = async (value: unknown): Promise<unknown> => {
        if (!value || typeof value !== 'object') return value;
        if ((value as Partial<BinaryDescriptor>).__foliaBinary === true) {
            const descriptor = value as BinaryDescriptor;
            let buffer: ArrayBuffer;
            try {
                const response = await fetch(Capacitor.convertFileSrc(descriptor.path));
                if (!response.ok) throw new Error('Cannot read Android binary response');
                buffer = await response.arrayBuffer();
            } finally {
                await native.binaryRelease({ path: descriptor.path }).catch(error => console.warn('[AndroidBinary] Cannot release response', error));
            }
            if (descriptor.type === 'ArrayBuffer') return buffer;
            const constructors: Record<string, new (buffer: ArrayBuffer) => ArrayBufferView> = {
                Uint8Array, Uint8ClampedArray, Int8Array, Uint16Array, Int16Array, Uint32Array, Int32Array, Float32Array, Float64Array,
            };
            if (!constructors[descriptor.type]) throw new Error('Unknown Android binary response type');
            return new constructors[descriptor.type](buffer);
        }
        if (Array.isArray(value)) {
            const result = [];
            for (const item of value) result.push(await decode(item));
            return result;
        }
        const result: Record<string, unknown> = {};
        for (const [key, item] of Object.entries(value)) result[key] = await decode(item);
        return result;
    };
    return { encode, decode };
};

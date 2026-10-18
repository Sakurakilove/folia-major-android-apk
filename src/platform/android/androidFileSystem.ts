import { Capacitor, registerPlugin } from '@capacitor/core';

// Serializable directory handles retain Android SAF grants across library reloads.
interface Descriptor { __foliaAndroidHandle: true; uri: string; name: string; kind: 'file' | 'directory'; }
interface FilePlugin {
    beginWrite(options: { uri: string; keepExistingData: boolean }): Promise<{ token: string }>;
    writeChunk(options: { token: string; position: number; data: string }): Promise<void>;
    truncateWrite(options: { token: string; size: number }): Promise<void>;
    finishWrite(options: { token: string; abort?: boolean }): Promise<void>;
    pickDirectory(): Promise<Descriptor>;
    pickFiles(options: {multiple: boolean; mimeTypes: string[]}): Promise<{entries: Descriptor[]}>;
    list(options: { uri: string }): Promise<{ entries: Descriptor[] }>;
    stat(options: { uri: string }): Promise<Descriptor & { mimeType: string; size: number; lastModified: number }>;
    create(options: { uri: string; name: string; mimeType: string }): Promise<Descriptor>;
    remove(options: { uri: string }): Promise<void>;
    queryDocumentPermission(options: { uri: string; mode: string }): Promise<{ state: PermissionState }>;
    requestDocumentPermission(options: { uri: string; mode: string; kind: string }): Promise<{ state: PermissionState }>;
    stage(options: { uri: string }): Promise<{ path: string }>;
}
const native = registerPlugin<FilePlugin>('FoliaFileSystem');
const fileUris = new WeakMap<File, string>();
const fail = (message: string, name: string): never => { throw new DOMException(message, name); };

class AndroidHandle {
    readonly __foliaAndroidHandle = true;
    readonly uri: string;
    readonly kind: 'file' | 'directory';
    readonly name: string;
    constructor(descriptor: Descriptor) { this.uri = descriptor.uri; this.kind = descriptor.kind; this.name = descriptor.name; }
    async isSameEntry(other: AndroidHandle): Promise<boolean> { return other?.uri === this.uri; }
    async queryPermission(options?: { mode?: 'read' | 'readwrite' }): Promise<PermissionState> {
        return (await native.queryDocumentPermission({ uri: this.uri, mode: options?.mode ?? 'read' })).state;
    }
    async requestPermission(options?: { mode?: 'read' | 'readwrite' }): Promise<PermissionState> {
        return (await native.requestDocumentPermission({ uri: this.uri, mode: options?.mode ?? 'read', kind: this.kind })).state;
    }
}

class AndroidFileHandle extends AndroidHandle {
    async createWritable(options?: { keepExistingData?: boolean }): Promise<WritableStream<FileSystemWriteChunkType> & { write: (data: FileSystemWriteChunkType) => Promise<void>; seek: (position: number) => Promise<void>; truncate: (size: number) => Promise<void>; close: () => Promise<void> }> {
        const { token } = await native.beginWrite({ uri: this.uri, keepExistingData: Boolean(options?.keepExistingData) });
        let position = 0;
        const validOffset = (value: unknown): number => {
            if (!Number.isSafeInteger(value) || Number(value) < 0) return fail('Invalid file offset', 'TypeError');
            return Number(value);
        };
        const stream = new WritableStream<FileSystemWriteChunkType>({
            write: async command => {
                let data: Blob | BufferSource | string;
                if (typeof command === 'object' && command !== null && !(command instanceof Blob) && 'type' in command) {
                    if (command.type === 'seek') { position = validOffset(command.position); return; }
                    if (command.type === 'truncate') {
                        const size = validOffset(command.size); await native.truncateWrite({ token, size }); position = Math.min(position, size); return;
                    }
                    if (command.type !== 'write' || command.data == null) return fail('Invalid write command', 'TypeError');
                    if (command.position !== undefined) position = validOffset(command.position);
                    data = command.data;
                } else data = command;
                const bytes = new Uint8Array(await new Blob([data as BlobPart]).arrayBuffer());
                for (let offset = 0; offset < bytes.length; offset += 65536) {
                    const chunk = bytes.subarray(offset, offset + 65536);
                    let binary = ''; for (const byte of chunk) binary += String.fromCharCode(byte);
                    await native.writeChunk({ token, position, data: btoa(binary) }); position += chunk.length;
                }
            },
            close: () => native.finishWrite({ token }),
            abort: () => native.finishWrite({ token, abort: true }),
        });
        const write = async (data: FileSystemWriteChunkType) => { const writer = stream.getWriter(); try { await writer.write(data); } finally { writer.releaseLock(); } };
        return Object.assign(stream, { write, seek: (offset: number) => write({ type: 'seek', position: offset }),
            truncate: (size: number) => write({ type: 'truncate', size }),
            close: async () => { const writer = stream.getWriter(); try { await writer.close(); } finally { writer.releaseLock(); } },
        });
    }

    async getFile(): Promise<File> {
        const info = await native.stat({ uri: this.uri });
        const response = await fetch(Capacitor.convertFileSrc(this.uri));
        if (!response.ok) return fail('Cannot read this document', 'NotReadableError');
        const file = new File([await response.blob()], this.name, { type: info.mimeType, lastModified: info.lastModified });
        fileUris.set(file, this.uri);
        return file;
    }
}

class AndroidDirectoryHandle extends AndroidHandle {
    async resolve(possibleDescendant: AndroidHandle): Promise<string[] | null> {
        if (await this.isSameEntry(possibleDescendant)) return [];
        const visited = new Set<string>([this.uri]);
        const queue: Array<{ handle: AndroidDirectoryHandle; path: string[] }> = [{ handle: this, path: [] }];
        for (let index = 0; index < queue.length; index++) {
            const parent = queue[index];
            for await (const [name, child] of parent.handle.entries()) {
                const segments = [...parent.path, name];
                if (await child.isSameEntry(possibleDescendant)) return segments;
                if (child.kind === 'directory' && !visited.has(child.uri)) {
                    visited.add(child.uri); queue.push({ handle: child as AndroidDirectoryHandle, path: segments });
                }
            }
        }
        return null;
    }
    async *entries(): AsyncGenerator<[string, AndroidHandle]> {
        const result = await native.list({ uri: this.uri });
        for (const descriptor of result.entries) yield [descriptor.name, revive(descriptor)];
    }
    async *values(): AsyncGenerator<AndroidHandle> { for await (const [, handle] of this.entries()) yield handle; }
    async *keys(): AsyncGenerator<string> { for await (const [name] of this.entries()) yield name; }
    [Symbol.asyncIterator](): AsyncGenerator<[string, AndroidHandle]> { return this.entries(); }
    private async child(name: string, kind: 'file' | 'directory', create = false): Promise<AndroidHandle> {
        if (!name || name === '.' || name === '..' || /[/\\]/.test(name)) return fail('Invalid document name', 'TypeError');
        for await (const [entryName, handle] of this.entries()) {
            if (entryName !== name) continue;
            if (handle.kind !== kind) return fail('The entry has another type', 'TypeMismatchError');
            return handle;
        }
        if (!create) return fail('Document not found', 'NotFoundError');
        return revive(await native.create({ uri: this.uri, name, mimeType: kind === 'directory' ? 'vnd.android.document/directory' : 'application/octet-stream' }));
    }
    getDirectoryHandle(name: string, options?: { create?: boolean }): Promise<AndroidHandle> { return this.child(name, 'directory', options?.create); }
    getFileHandle(name: string, options?: { create?: boolean }): Promise<AndroidHandle> { return this.child(name, 'file', options?.create); }
    async removeEntry(name: string, options?: { recursive?: boolean }): Promise<void> {
        for await (const [entryName, handle] of this.entries()) {
            if (entryName !== name) continue;
            if (handle.kind === 'directory' && !options?.recursive) {
                for await (const _ of (handle as AndroidDirectoryHandle).entries()) return fail('Directory is not empty', 'InvalidModificationError');
            }
            await native.remove({ uri: handle.uri });
            return;
        }
        fail('Document not found', 'NotFoundError');
    }
}

const revive = (descriptor: Descriptor): AndroidHandle => descriptor.kind === 'directory'
    ? new AndroidDirectoryHandle(descriptor) : new AndroidFileHandle(descriptor);

export const reviveAndroidDirectoryHandles = <T>(handles: T): T => {
    if (!Capacitor.isNativePlatform() || !handles || typeof handles !== 'object') return handles;
    if ((handles as Partial<Descriptor>).__foliaAndroidHandle === true) return revive(handles as unknown as Descriptor) as T;
    if (Array.isArray(handles)) return handles.map(reviveAndroidDirectoryHandles) as T;
    return Object.fromEntries(Object.entries(handles).map(([key, value]) => [key,
        value?.__foliaAndroidHandle === true ? revive(value as Descriptor) : value])) as T;
};

export const installAndroidFileSystem = (): void => {
    const picker = async <T>(operation: Promise<T>): Promise<T> => {
        try { return await operation; } catch(error) {
            if(['AbortError','ABORT_ERR'].includes((error as {code?: string}).code ?? '')) throw new DOMException('File selection was cancelled','AbortError');
            throw error;
        }
    };
    Object.assign(window, {
        showDirectoryPicker: async () => revive(await picker(native.pickDirectory())),
        showOpenFilePicker: async (options?: {multiple?: boolean; types?: Array<{accept: Record<string,string[]>}>}) => {
            const mimeTypes=[...new Set((options?.types || []).flatMap(type=>Object.keys(type.accept)))];
            const result=await picker(native.pickFiles({multiple:options?.multiple === true,mimeTypes}));
            return result.entries.map(revive);
        },
    });
};

export const getAndroidFileUri = (file: File): string => fileUris.get(file) ?? '';
export const stageAndroidDocument = async (uri: string): Promise<string> => (await native.stage({ uri })).path;

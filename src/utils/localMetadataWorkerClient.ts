export interface EmbeddedMetadataResult {
    title?: string;
    artist?: string;
    artists?: string[];
    album?: string;
    trackNumber?: number;
    discNumber?: number;
    cover?: Blob;
    coverAssetId?: string;
    bitrate?: number;
    lyrics?: string;
    translationLyrics?: string;
    replayGain?: number;
    replayGainTrackGain?: number;
    replayGainTrackPeak?: number;
    replayGainAlbumGain?: number;
    replayGainAlbumPeak?: number;
    duration?: number;
}

export interface HashedLocalCoverResult {
    cover: Blob;
    coverAssetId: string;
}

// Own requests with their worker generation so failures release every retained File/Blob.
const REQUEST_TIMEOUT_MS = 120000;
let metadataWorker: Worker | null = null;
let workerRequestId = 0;
const workerCallbacks = new Map<string, { finish: (result: unknown | null) => void; timer: ReturnType<typeof setTimeout> }>();

const finishRequest = (requestId: string, result: unknown | null) => {
    const pending = workerCallbacks.get(requestId);
    if (!pending) return;
    workerCallbacks.delete(requestId);
    clearTimeout(pending.timer);
    pending.finish(result);
};

const discardWorker = (worker: Worker) => {
    if (metadataWorker !== worker) return;
    metadataWorker = null;
    worker.onmessage = null;
    worker.onerror = null;
    worker.onmessageerror = null;
    worker.terminate();
    for (const requestId of [...workerCallbacks.keys()]) finishRequest(requestId, null);
};

export const initMetadataWorker = (): Worker => {
    if (!metadataWorker) {
        const worker = new Worker(
            new URL('../workers/metadataParser.worker.ts', import.meta.url),
            { type: 'module' }
        );
        metadataWorker = worker;
        worker.onmessage = (event) => {
            if (metadataWorker !== worker) return;
            const message = event.data;
            if (!message || typeof message.requestId !== 'string') return;
            if (message.type !== 'result') console.warn('[MetadataWorker] parsing error:', message.message);
            finishRequest(message.requestId, message.type === 'result' ? message.data : null);
        };
        worker.onerror = (event) => {
            event.preventDefault();
            console.warn('[MetadataWorker] Worker failed:', event.message);
            discardWorker(worker);
        };
        worker.onmessageerror = () => discardWorker(worker);
    }
    return metadataWorker;
};

const requestMetadata = <T,>(prefix: string, payload: Record<string, unknown>): Promise<T | null> => (
    new Promise(resolve => {
        let worker: Worker;
        try { worker = initMetadataWorker(); }
        catch (error) {
            console.warn('[MetadataWorker] Cannot create worker:', error);
            resolve(null);
            return;
        }
        const requestId = `${prefix}_${++workerRequestId}`;
        const timer = setTimeout(() => discardWorker(worker), REQUEST_TIMEOUT_MS);
        workerCallbacks.set(requestId, { finish: result => resolve(result as T | null), timer });
        try { worker.postMessage({ ...payload, requestId }); }
        catch (error) {
            console.warn('[MetadataWorker] Cannot post request:', error);
            finishRequest(requestId, null);
        }
    })
);

export const parseEmbeddedMetadataAsync = (
    file: File,
    includeCover = false
): Promise<EmbeddedMetadataResult | null> => requestMetadata('meta_req', { type: 'parse-metadata', file, includeCover });

export const hashLocalCoverBlobAsync = (cover: Blob): Promise<HashedLocalCoverResult | null> => (
    requestMetadata('cover_hash_req', { type: 'hash-cover', cover })
);

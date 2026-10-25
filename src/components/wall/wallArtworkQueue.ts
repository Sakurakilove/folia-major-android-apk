// Bound artwork upgrades and remove abandoned work before it consumes a decode slot.
export const createWallArtworkQueue = (concurrency: number, maxWaiting = 256) => {
    concurrency = Math.max(1, Math.floor(concurrency));
    let active = 0;
    const waiting: Array<() => void> = [];
    return <T>(task: () => Promise<T>, signal?: AbortSignal): Promise<T> => new Promise((resolve, reject) => {
        const aborted = () => new DOMException('Artwork request was cancelled', 'AbortError');
        let started = false;
        const cancel = () => {
            if (started) return; // The running decoder owns cancellation and slot release.
            const index = waiting.indexOf(run);
            if (index !== -1) waiting.splice(index, 1);
            signal?.removeEventListener('abort', cancel);
            reject(aborted());
        };
        const run = () => {
            signal?.removeEventListener('abort', cancel);
            if (signal?.aborted) { reject(aborted()); return; }
            started = true;
            active++;
            void Promise.resolve().then(task).then(resolve, reject).finally(() => {
                active--;
                waiting.shift()?.();
            });
        };
        if (signal?.aborted) { reject(aborted()); return; }
        if (active < concurrency) run();
        else if (waiting.length < maxWaiting) {
            waiting.push(run);
            signal?.addEventListener('abort', cancel, { once: true });
        } else reject(new DOMException('Artwork queue is full; retry when visible', 'AbortError'));
    });
};

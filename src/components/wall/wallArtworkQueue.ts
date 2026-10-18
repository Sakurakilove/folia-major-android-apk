// Bound simultaneous artwork upgrades; callers still deduplicate requests by URL.
export const createWallArtworkQueue = (concurrency: number) => {
    let active = 0;
    const waiting: Array<() => void> = [];
    return <T>(task: () => Promise<T>): Promise<T> => new Promise((resolve, reject) => {
        const run = () => {
            active++;
            void Promise.resolve().then(task).then(resolve, reject).finally(() => {
                active--;
                waiting.shift()?.();
            });
        };
        if (active < concurrency) run();
        else waiting.push(run);
    });
};

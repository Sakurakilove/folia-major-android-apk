import spec from '../../../shared/androidApiSpec.json';
import { registerPlugin } from '@capacitor/core';

// Forward the actual desktop IPC contract and queued native interactions across one reconnectable event feed.
type Invoke = (method: string, ...args: unknown[]) => Promise<unknown>;
interface ShellPlugin { shell(options: { method: string; args: unknown[]; requestId?: string }): Promise<{ result: unknown }>; }
interface PollResult {
    cursor: number;
    entries: Array<{ id: number; channel: string; args: unknown[] }>;
    action: { id: string; method: string; args: unknown[]; requestId?: string } | null;
}
export const installAndroidEvents = (bridge: Record<string, unknown>, invoke: Invoke, methods: string[], windowId = 1): void => {
    const listeners = new Map<string, Set<(...args: unknown[]) => void>>();
    const shell = registerPlugin<ShellPlugin>('FoliaRuntime');
    const put = (name: string, value: unknown) => {
        const parts = name.split('.');
        const object = parts.length === 1 ? bridge : (bridge[parts[0]] ??= {}) as Record<string, unknown>;
        object[parts.at(-1)!] = value;
    };
    for (const [name, item] of Object.entries(spec) as Array<[string, { channel?: string; send?: string; event?: string }]>) {
        if (item.event) {
            put(name, (callback: (...args: unknown[]) => void) => {
                const set = listeners.get(item.event!) ?? new Set();
                let caughtUp = name !== 'onDebugMainLines';
                const listener = (...args: unknown[]) => {
                    if (name === 'onDebugMainLines') { caughtUp ||= args[1] === true; if (caughtUp) callback(args[0]); }
                    else if (name === 'onRemoteControlPointerInside') callback(Boolean(args[0]));
                    else callback(...args);
                };
                set.add(listener); listeners.set(item.event!, set);
                if (item.send) void invoke('_send', item.send).catch(error => console.warn('[AndroidIPC] Subscription setup failed', error));
                return () => { set.delete(listener); if (!set.size) listeners.delete(item.event!); };
            });
        } else if (methods.includes(name)) {
            put(name, (...args: unknown[]) => invoke(name, ...args));
        }
    }
    let cursor = 0;
    let stopped = false;
    let generation = 0;
    const poll = async (epoch = generation) => {
        let failed = false;
        try {
            const result = await invoke(methods.includes('_waitEvents') ? '_waitEvents' : '_poll', cursor, windowId) as PollResult;
            if (stopped || epoch !== generation) return;
            cursor = result.cursor;
            for (const event of result.entries) {
                for (const listener of listeners.get(event.channel) ?? []) {
                    try { listener(...event.args); } catch (error) { console.warn('[AndroidIPC] Event listener failed', error); }
                }
            }
            if (result.action) {
                const action = result.action;
                void shell.shell({ method: action.method, args: action.args, requestId: action.id }).then(
                    answer => invoke('_completeNative', action.id, answer.result, null),
                    error => invoke('_completeNative', action.id, null, String(error?.message || error)),
                ).catch(error => console.warn('[AndroidIPC] Native response failed', error));
            }
        } catch (error) { failed = true; console.warn('[AndroidIPC] Event connection failed', error); }
        if (!stopped && epoch === generation) setTimeout(() => void poll(epoch), failed ? 1000 : methods.includes('_waitEvents') ? 0 : 500);
    };
    window.addEventListener('pagehide', () => { stopped = true; generation++; }, { once: true });
    window.addEventListener('pageshow', () => { if (stopped) { stopped = false; void poll(); } });
    void poll();
};

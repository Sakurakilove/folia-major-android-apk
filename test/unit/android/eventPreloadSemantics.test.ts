import { afterEach, describe, expect, it, vi } from 'vitest';
import { installAndroidEvents } from '../../../src/platform/android/androidEvents';
vi.mock('@capacitor/core', () => ({ registerPlugin: () => ({ shell: vi.fn() }) }));

// A queued live log before subscription must not duplicate the desktop backlog delivered after readiness.
afterEach(() => { vi.unstubAllGlobals(); vi.useRealTimers(); });
describe('Android desktop event subscription semantics', () => {
    it('waits for log backlog readiness and removes the actual forwarding listener', async () => {
        vi.useFakeTimers();
        const window = new EventTarget(); vi.stubGlobal('window',window);
        let answer!: (result: unknown) => void;
        const invoke = vi.fn((method: string) => method === '_waitEvents' ? new Promise(resolve => { answer=resolve; }) : Promise.resolve(true));
        const bridge: Record<string, any> = {};
        installAndroidEvents(bridge,invoke,['_waitEvents']);
        const listener=vi.fn(); const remove=bridge.onDebugMainLines(listener);
        answer({cursor:3,action:null,entries:[
            {id:1,channel:'debug-main-lines',args:[['old-live'],false]},
            {id:2,channel:'debug-main-lines',args:[['backlog'],true]},
            {id:3,channel:'debug-main-lines',args:[['new-live'],false]},
        ]});
        await Promise.resolve(); await Promise.resolve();
        expect(listener.mock.calls).toEqual([[['backlog']],[['new-live']]]);
        remove();
        await vi.advanceTimersByTimeAsync(1);
        answer({cursor:4,action:null,entries:[{id:4,channel:'debug-main-lines',args:[['removed'],false]}]});
        await Promise.resolve(); await Promise.resolve();
        expect(listener).toHaveBeenCalledTimes(2);
        window.dispatchEvent(new Event('pagehide'));
    });
});

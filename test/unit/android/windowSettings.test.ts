import { describe, expect, it, vi } from 'vitest';
import { createRequire } from 'node:module';
import { EventEmitter } from 'node:events';
const require = createRequire(import.meta.url);
const createControls = require('../../../packaging/android/runtime/windowControls.cjs');

// Settings must change actual native operations, and failed operations must retain the last effective state.
const setup = () => {
    const values = new Map<string, unknown>();
    const store = { get: (key: string, fallback?: unknown) => values.has(key) ? values.get(key) : fallback,
        set: (key: string, value: unknown) => values.set(key, value), delete: (key: string) => values.delete(key) };
    let current: WindowPeer;
    class WindowPeer extends EventEmitter {
        id = 2;
        webContents = { send: vi.fn() };
        setAlwaysOnTop = vi.fn(async () => {});
        setIgnoreMouseEvents = vi.fn(async () => {});
        setTitlebarVisible = vi.fn(async () => {});
        setSkipTaskbar = vi.fn(async () => {});
        loadFile = vi.fn(async () => {});
        show = vi.fn(async () => {});
        isDestroyed = () => false;
        close = () => this.emit('closed');
        constructor(public options: Record<string, unknown>) { super(); current = this; }
        static fromId = () => current;
    }
    const native = vi.fn(async () => true);
    const controls = createControls({ store, events: { native, emit: vi.fn() },
        platform: { electron: { BrowserWindow: WindowPeer }, context: { getStore: () => ({ windowId: 1 }) } } });
    return { controls, store, native, remote: () => current! };
};

describe('Android window setting actions', () => {
    it('uses the desktop titlebar default and applies later titlebar and topmost setting changes', async () => {
        const { controls, store, remote } = setup();
        await controls.openRemoteControl();
        expect(remote().options.frame).toBe(true);
        store.set('REMOTE_CONTROL_HIDE_TITLEBAR', true); await controls._applyWindowSetting('REMOTE_CONTROL_HIDE_TITLEBAR');
        expect(remote().setTitlebarVisible).toHaveBeenCalledWith(false);
        store.set('REMOTE_CONTROL_ALWAYS_ON_TOP', false); await controls._applyWindowSetting('REMOTE_CONTROL_ALWAYS_ON_TOP');
        expect(remote().setAlwaysOnTop).toHaveBeenLastCalledWith(false);
        store.set('REMOTE_CONTROL_SKIP_TASKBAR',true); await controls._applyWindowSetting('REMOTE_CONTROL_SKIP_TASKBAR');
        expect(remote().setSkipTaskbar).toHaveBeenLastCalledWith(true);
    });
    it('persists topmost state only after Android has accepted the change', async () => {
        const { controls, store, native } = setup();
        await controls.setMainWindowAlwaysOnTop(true);
        native.mockRejectedValueOnce(new Error('Android refused the window'));
        await expect(controls.setMainWindowAlwaysOnTop(false)).rejects.toThrow('Android refused');
        expect(store.get('MAIN_WINDOW_ALWAYS_ON_TOP')).toBe(true);
        expect(controls.getMainWindowAlwaysOnTop()).toBe(true);
    });
    it('distinguishes closing the player from sending it to the background', async () => {
        const { controls, store, native } = setup();
        await controls.closeWindow(); expect(native).toHaveBeenLastCalledWith('quitApp');
        store.set('CLOSE_TO_TRAY', true); await controls.closeWindow();
        expect(native).toHaveBeenCalledWith('hideTaskbar', true);
        expect(native).toHaveBeenLastCalledWith('windowHide', 1);
    });
});

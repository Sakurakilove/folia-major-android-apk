const path = require('node:path');
module.exports = ({ platform, store, events }) => {
    const { BrowserWindow } = platform.electron;
    const flag = (key, fallback = false) => store.getBoolean ? store.getBoolean(key, fallback) : Boolean(store.get(key, fallback));
    const handoff = require('./electron/windowPlaybackHandoff.cjs').createWindowPlaybackHandoffStore({ storage: store });
    let remote = null, snapshot = null, fullscreen = false, remotePointer = false;
    let mainTop = false, mainClickThrough = false, unlockHover = false;
    const native = (method, ...args) => events.native(method, platform.context.getStore()?.windowId || 1, ...args);
    const remoteSettings = () => ({ alwaysOnTop: flag('REMOTE_CONTROL_ALWAYS_ON_TOP', true),
        skipTaskbar: flag('REMOTE_CONTROL_SKIP_TASKBAR', false), hideTitlebar: flag('REMOTE_CONTROL_HIDE_TITLEBAR', false),
        clickThrough: flag('REMOTE_CONTROL_CLICK_THROUGH', false) });
    const syncStatus = () => ({ remoteControlOpen: Boolean(remote && !remote.isDestroyed()),
        discordPresenceEnabled: flag('DISCORD_RICH_PRESENCE_ENABLED', false) });
    const broadcast = () => events.emit('playback-sync-bridge-status-changed', syncStatus());
    const open = async () => {
        if (remote && !remote.isDestroyed()) { await remote.setAlwaysOnTop(remoteSettings().alwaysOnTop); await remote.setIgnoreMouseEvents(remoteSettings().clickThrough); await remote.show(); return true; }
        remote = new BrowserWindow({ width: 420, height: 320, show: true, transparent: true, frame: !remoteSettings().hideTitlebar, name: 'folia-remote', privileged: true, skipTaskbar: remoteSettings().skipTaskbar });
        remote.once('closed', () => { remote = null; broadcast(); });
        await remote.loadFile(path.join(__dirname, 'dist/index.html'), { query: { remote: '1' } });
        await remote.setAlwaysOnTop(remoteSettings().alwaysOnTop);
        await remote.setIgnoreMouseEvents(remoteSettings().clickThrough);
        if (snapshot) remote.webContents.send('remote-control-snapshot', snapshot);
        broadcast(); return true;
    };
    const close = () => { remote?.close(); remote = null; broadcast(); return true; };
    const toggleFullscreen = async () => {
        fullscreen = Boolean(await native('windowFullscreen', !fullscreen)); events.emit('window-fullscreen-changed', fullscreen); return fullscreen;
    };
    return {
        _androidRendererExited: (id, details) => {
            console.warn('[AndroidRenderer] Renderer exited', { windowId: Number(id), didCrash: details?.didCrash, priorityAtExit: details?.priorityAtExit });
            const window=BrowserWindow.fromId(Number(id));if(!window)return false;
            window.webContents.crashed=true;if(Number(id)===1)platform.recordRendererMetrics?.(null);return true;
        },
        _androidRendererReady: () => {
            const window=BrowserWindow.fromId(platform.context.getStore()?.windowId || 1);
            if(window)window.webContents.crashed=false;return Boolean(window);
        },
        _androidWindowClosed: id => {
            const window = BrowserWindow.fromId(Number(id));
            if (!window || Number(id) === 1) return false;
            window.nativeClosed(); return true;
        },
        _androidMainWindowRestored: () => {
            mainTop = false; mainClickThrough = false; unlockHover = false;
            store.set('MAIN_WINDOW_ALWAYS_ON_TOP', false);
            events.emit('main-window-click-through-changed', { enabled: false, unlockHoverActive: false });
            return true;
        },
        quitApp: () => events.native('quitApp'),
        _androidDisplaysChanged: async () => { const status=await events.native('wallpaperDisplays');events.emit('wallpaper-displays-changed',status);return true; },
        getWallpaperDisplays: () => events.native('wallpaperDisplays'),
        setWallpaperDisplay: id => events.native('wallpaperSetDisplay', id),
        openRemoteControl: open, closeRemoteControl: close, toggleRemoteControl: () => remote ? close() : open(),
        getRemoteControlSnapshot: () => snapshot,
        publishRemoteControlSnapshot: next => { snapshot = next; remote?.webContents.send('remote-control-snapshot', next); return true; },
        sendRemoteControlCommand: command => { events.emit('remote-control-command', command); return true; },
        _restoreNativeWindowEffects: () => native('windowBlur',flag('enable_player_page_native_blur') && !flag('TRANSPARENT_PLAYER_BACKGROUND')),
        _applyWindowSetting: async key => {
            if(key === 'enable_player_page_native_blur') await native('windowBlur',flag(key) && !flag('TRANSPARENT_PLAYER_BACKGROUND'));
            if (key === 'HIDE_TASKBAR_ICON') await events.native('hideTaskbar',flag(key));
            if (key === 'REMOTE_CONTROL_SKIP_TASKBAR' && remote) await remote.setSkipTaskbar(flag(key));
            if (key === 'REMOTE_CONTROL_HIDE_TITLEBAR' && remote) await remote.setTitlebarVisible(!flag(key));
            if (key === 'REMOTE_CONTROL_ALWAYS_ON_TOP' && remote) {
                if (!flag(key) && remoteSettings().clickThrough) throw new Error('Disable click-through before leaving floating mode');
                await remote.setAlwaysOnTop(flag(key));
            }
            if (key === 'REMOTE_CONTROL_CLICK_THROUGH' && remote) {
                await remote.setIgnoreMouseEvents(flag(key));
                if (flag(key)) { remotePointer=false; events.emit('remote-control-pointer-inside',false); }
            }
            if (key.startsWith('REMOTE_CONTROL_')) events.emit('remote-control-window-settings-changed',remoteSettings());
        },
        _androidPointerState: inside => {
            if (platform.context.getStore()?.windowId !== remote?.id) return false;
            remotePointer = Boolean(inside) && !remoteSettings().clickThrough;
            events.emit('remote-control-pointer-inside',remotePointer); return remotePointer;
        },
        getRemoteControlPointerInside: () => remotePointer,
        getRemoteControlWindowSettings: remoteSettings,
        getRemoteControlAlwaysOnTop: () => remoteSettings().alwaysOnTop,
        setRemoteControlAlwaysOnTop: async enabled => {
            if (!enabled && remoteSettings().clickThrough) throw new Error('Disable click-through before leaving floating mode');
            if (remote) await remote.setAlwaysOnTop(enabled);
            store.set('REMOTE_CONTROL_ALWAYS_ON_TOP', Boolean(enabled)); events.emit('remote-control-window-settings-changed', remoteSettings()); return Boolean(enabled);
        },
        getPlaybackSyncBridgeStatus: syncStatus,
        isWindowMaximized: () => native('windowIsMaximized'),
        toggleMaximizeWindow: async () => { const result = await native('windowToggleMaximize'); if (result.floating) mainTop = true; return result.maximized; },
        toggleFullscreenWindow: toggleFullscreen, isWindowFullscreen: () => fullscreen,
        setNativeTheme: theme => native('windowTheme', theme),
        closeWindow: async () => {
            const id = platform.context.getStore()?.windowId || 1;
            if (id !== 1) { BrowserWindow.fromId(id)?.close(); return true; }
            if (!flag('CLOSE_TO_TRAY', false)) return events.native('quitApp');
            await events.native('hideTaskbar', true); return native('windowHide');
        },
        minimizeWindow: async () => {
            if ((platform.context.getStore()?.windowId || 1) === 1) await events.native('hideTaskbar', (flag('HIDE_TASKBAR_ICON') || flag('MINIMIZE_TO_TRAY')));
            return native('windowHide');
        },
        consumeWindowPlaybackHandoff: () => handoff.consume(),
        submitWindowPlaybackHandoff: (_id, state) => handoff.save(state),
        getWindowTransparentMode: () => flag('TRANSPARENT_PLAYER_BACKGROUND', false),
        setWindowTransparentMode: async (enabled, state) => {
            if (enabled && !mainTop) { await native('windowTop', true); mainTop = true; store.set('MAIN_WINDOW_ALWAYS_ON_TOP', true); }
            await native('windowTransparent', Boolean(enabled));
            if (state) handoff.save(state);
            store.set('TRANSPARENT_PLAYER_BACKGROUND', Boolean(enabled));
            if(!enabled && flag('enable_player_page_native_blur')) await native('windowBlur',true);
            return Boolean(enabled);
        },
        getMainWindowAlwaysOnTop: () => mainTop,
        setMainWindowAlwaysOnTop: async enabled => { if (!enabled && mainClickThrough) throw new Error('Disable click-through before leaving floating mode'); await native('windowTop', Boolean(enabled)); mainTop = Boolean(enabled); store.set('MAIN_WINDOW_ALWAYS_ON_TOP', mainTop); return mainTop; },
        getMainWindowClickThroughEnabled: () => mainClickThrough,
        setMainWindowClickThroughEnabled: async enabled => {
            await native('windowClickThrough', Boolean(enabled)); mainClickThrough = Boolean(enabled);
            events.emit('main-window-click-through-changed', { enabled: mainClickThrough, unlockHoverActive: unlockHover }); return mainClickThrough;
        },
        setMainWindowClickThroughUnlockHover: async active => {
            unlockHover = Boolean(active) && mainClickThrough; await native('windowClickThrough', mainClickThrough && !unlockHover);
            return unlockHover;
        },
    };
};

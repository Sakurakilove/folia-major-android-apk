const path = require('node:path');
const fs = require('node:fs');

// Keep protocol, model, provider, Stage and mod behavior in the upstream implementations.
module.exports = async ({ platform, store, events, safeStorage, netease, dataDir, network, getConfiguredCacheDirectory }) => {
    const { app, protocol, net, mainWindow, electron } = platform;
    require('./electron/debug/debugHost.cjs').createDebugHost({ app, ipcMain: platform.ipcMain, store, BrowserWindow: electron.BrowserWindow });
    const { createStageApi } = require('./electron/stageApi.cjs');
    const stage = createStageApi({ app, store, getMainWindow: () => mainWindow,
        stageModeEnabledSettingKey: 'STAGE_MODE_ENABLED', stageModeSourceSettingKey: 'STAGE_MODE_SOURCE',
        stageApiTokenSettingKey: 'STAGE_API_TOKEN', stageApiPortSettingKey: 'STAGE_API_PORT',
        defaultStageApiPort: 32107, getNeteasePort: () => netease.getPort() });
    const lyric = require('./electron/lyricApi.cjs').createLyricApi({ store, getMainWindow: () => mainWindow,
        enabledSettingKey: 'LYRIC_API_ENABLED', port: 32109 });
    const covers = require('./electron/localCoverAssets.cjs').createLocalCoverAssetStore({
        getDirectory: () => path.join(dataDir, 'local-cover-assets'),
    });
    covers.registerProtocolHandler(protocol, net);
    let mediaCache;
    const transcode = require('./electron/transcode/service.cjs').createTranscodeService({ app, protocol, net, onCacheWrite: (...args) => mediaCache?._pruneAudioCache(...args) });
    await transcode.initialize();
    const spotify = require('./electron/spotify/spotifyApiBridge.cjs').createSpotifyApiBridge({
        store, safeStorage, fetch: (url, options) => network.fetch(url, options, true), openExternal: electron.shell.openExternal,
        language: () => store.get('APP_LOCALE', 'zh-CN'), audioDirectory: () => path.join(getConfiguredCacheDirectory(), 'spotify'),
        onAudioKept: limit => mediaCache._pruneAudioCache(limit),
    });
    mediaCache = require('./generated/mediaCache.cjs')({ getConfiguredCacheDirectory, transcodeService: transcode, spotifyApiBridge: spotify });
    protocol.handle('folia-spotify', request => spotify.handleAudioRequest(request));
    const ytmBrowser = require('./ytmBrowser.cjs')({ events });
    const ytm = require('./electron/ytm/ytmApiBridge.cjs').createYtmApiBridge({
        store, safeStorage, fetch: (url, options) => network.fetch(url, options, true), language: () => store.get('APP_LOCALE', 'zh-CN'),
        evaluate: async code => {
            const answer = await events.native('sandboxEvaluate', code);
            if (answer.error) throw new Error(answer.error);
            return answer.value;
        },
        signInFolder: () => path.join(dataDir, 'ytm-sign-in'), browserSignIn: ytmBrowser, browserName: ytmBrowser.userAgent,
    });
    protocol.handle('folia-ytm', request => ytm.handleAudioRequest(request));
    const mods = require('./electron/modSystem/modSystem.cjs').createModSystem({
        app, BrowserWindow: electron.BrowserWindow, getMainWindow: () => mainWindow,
        getLocaleKey: () => store.get('APP_LOCALE', 'zh-CN'), isFeatureEnabled: () => store.getBoolean('MOD_SYSTEM_ENABLED', false),
    });
    mods.registerIpc(); mods.start();
    const writer = require('./electron/videoExportFileWriter.cjs').createVideoExportFileWriter({
        finalizeFile: require('./electron/videoExportMp4.cjs').finalizeVideoExportFile,
    });
    await Promise.all([stage.startStageServerIfNeeded(), lyric.start()]);
    const { createDiscordPresenceController, DEFAULT_DISCORD_APPLICATION_ID } = require('./electron/discordPresence.cjs');
    const discord = createDiscordPresenceController({
        getApplicationId: () => DEFAULT_DISCORD_APPLICATION_ID,
        isEnabled: () => store.getBoolean('DISCORD_RICH_PRESENCE_ENABLED', false),
        onStatusChange: status => events.emit('discord-presence-status-changed', status),
    });
    void discord.refresh().catch(error => console.warn('[Discord] Cannot initialize presence', error));
    const windows = require('./windowControls.cjs')({ platform, store, events });
    const renderer = require('./debugger.cjs')({ events, mainWindow, recordRendererMetrics: platform.recordRendererMetrics });
    const trustedRenderer = action => (...args) => {
        if (platform.context.getStore()?.windowId !== 1) throw new Error('Only the main renderer can configure video export');
        return action(...args);
    };
    const updates = require('./updates.cjs')({ platform, store, events, dataDir });
    const { _applyUpdateSetting, ...updateHandlers } = updates;
    return {
        handlers: {
            ...mediaCache,
            getDiscordPresenceStatus: () => discord.getStatus(),
            publishDiscordPresenceSnapshot: snapshot => discord.publishSnapshot(snapshot),
            debugGetRenderedFonts: renderer,
            debugRendererMemory: trustedRenderer(renderer.memory),
            reportDevicePixelRatio: trustedRenderer(renderer.reportDevicePixelRatio),
            prepareVideoExportWindow: trustedRenderer(renderer.prepareVideoExportWindow),
            restoreVideoExportWindow: trustedRenderer(renderer.restoreVideoExportWindow),
            ...updateHandlers,
            ...windows,
            ...require('./generated/obs.cjs')({ store, mainWindow }),
            ytmRequest: (operation, params) => ytm.request(operation, params),
            spotifyRequest: (operation, params) => spotify.request(operation, params),
            getStageStatus: () => stage.buildStageStatus(), setStageEnabled: enabled => stage.setStageEnabled(enabled),
            regenerateStageToken: () => stage.regenerateStageToken(), clearStageState: () => stage.clearStageState(),
            completeStageExternalPlayRequest: result => stage.completeStageExternalPlayRequest(result),
            publishStagePlayerSnapshot: (snapshot, options) => stage.publishStagePlayerSnapshot(snapshot, options),
            completeStagePlayerControlRequest: result => stage.completeStagePlayerControlRequest(result),
            completeStagePlayerQueueRequest: result => stage.completeStagePlayerQueueRequest(result),
            getLyricApiStatus: () => lyric.buildStatus(), setLyricApiEnabled: enabled => lyric.setEnabled(enabled),
            publishLyricApiData: (data, offset) => lyric.publishLyricData(data, offset),
            hasLocalCoverAsset: assetId => covers.has(assetId), saveLocalCoverAsset: async (...args) => { await covers.write(...args); return true; },
            removeLocalCoverAsset: assetId => covers.remove(assetId), clearLocalCoverAssets: () => covers.clear(),
            requestTranscodeFallback: request => transcode.request(request), cancelTranscodeFallback: id => transcode.cancel(id),
            chooseVideoExportPath: async (name, extension) => electron.dialog.showSaveDialog({ defaultPath: name || 'Folia-export.' + (extension === 'mp4' ? 'mp4' : 'webm') }),
            openVideoExportFile: file => writer.open(file), appendVideoExportChunk: (id, chunk) => writer.append(id, chunk),
            finishVideoExportFile: async id => { const result = await writer.finish(id); await app.publishAndroidExport(result.filePath); return result; }, abortVideoExportFile: id => writer.abort(id),
        },
        settingChanged: async key => {
            await windows._applyWindowSetting(key);
            void _applyUpdateSetting(key).catch(error => console.warn('[AndroidUpdate] Setting application failed', error));
            if (key === 'wallpaper_forward_mouse') await events.native('wallpaperTouch',store.get(key) !== false);
            if (key === 'DISCORD_RICH_PRESENCE_ENABLED') await discord.refresh();
            if (key === 'MOD_SYSTEM_ENABLED') { mods.loadAll(); if (store.getBoolean(key)) void mods.probeFfmpeg(); }
            if (key.startsWith('STAGE_')) await stage.syncStageModeState();
            if (key === 'LYRIC_API_ENABLED') await lyric.setEnabled(store.get(key));
        },
    };
};

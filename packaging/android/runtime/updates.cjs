const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');
module.exports = ({ store, events, dataDir, platform }) => {
    const releasesUrl = 'https://github.com/chthollyphile/folia-major/releases';
    const { resolveReleaseChannel, compareVersions, parseUpdateMetadataVersion } = require('./electron/updateChannels.cjs');
    const channel = () => resolveReleaseChannel(platform.app.getVersion(), store.get('UPDATE_CHANNEL'));
    const enabled = key => store.getBoolean ? store.getBoolean(key, false) : store.get(key, false) === true;
    let asset = null, downloaded = null, generation = 0, activeCheck = null, activeDownload = null;

    let state = { status: 'idle', supported: true, updateCheckSupported: true, updateCheckSupportReason: null,
        platform: 'android', updateCheckEnabled: store.get('ENABLE_UPDATE_CHECK', false), autoUpdateEnabled: store.get('ENABLE_AUTO_UPDATE', false),
        autoUpdateSupported: true, autoUpdateSupportReason: null, currentVersion: platform.app.getVersion(), availableVersion: null,
        updateUrl: releasesUrl, error: null, lastCheckedAt: null, lastSeenVersion: store.get('LAST_SEEN_UPDATE_VERSION', null), updateSeen: false, downloadProgress: null };
    const publish = patch => { state = { ...state, ...patch }; const result = status(); events.emit('update-status-changed', result); return result; };
    const status = () => ({ ...state, supported: channel().updateEnabled, updateCheckSupported: channel().updateEnabled,
        autoUpdateSupported: channel().updateEnabled, updateCheckSupportReason: channel().updateEnabled ? null : 'channel',
        autoUpdateSupportReason: channel().updateEnabled ? null : 'channel',
        updateCheckEnabled: enabled('ENABLE_UPDATE_CHECK'), autoUpdateEnabled: enabled('ENABLE_AUTO_UPDATE'),
        lastSeenVersion: store.get('LAST_SEEN_UPDATE_VERSION',null),
        updateSeen: Boolean(state.availableVersion && store.get('LAST_SEEN_UPDATE_VERSION') === state.availableVersion) });
    const check = async () => {
        if (!channel().updateEnabled) return publish({ status: 'unsupported', error: null });
        if (activeCheck) return activeCheck;
        const selected = channel(), current = generation;
        const controller = new AbortController();
        const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(30000)]);
        publish({ status: 'checking', error: null });
        const operation = (async () => {
            try {
                const suffix = selected.rollingReleaseTag ? '/tags/' + selected.rollingReleaseTag : '/latest';
                const response = await fetch('https://api.github.com/repos/chthollyphile/folia-major/releases' + suffix,
                    { headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'Folia-Android' }, signal });
                if (!response.ok) throw new Error('Release check failed: HTTP ' + response.status);
                const release = await response.json();
                let version = String(release.tag_name || '').replace(/^v/, '');
                if (selected.rollingReleaseTag) {
                    const metadata = (release.assets || []).find(item => item.name === selected.updaterChannel + '.yml');
                    if (!metadata) throw new Error('Release channel metadata is missing');
                    const result = await fetch(metadata.browser_download_url, { signal });
                    if (!result.ok) throw new Error('Release metadata failed: HTTP ' + result.status);
                    version = parseUpdateMetadataVersion(await result.text());
                }
                if (!/^\d+\.\d+\.\d+(?:[-+][a-z0-9.-]+)?$/i.test(version)) throw new Error('Release metadata contains no valid version');
                if (current !== generation) return status();
                const architecture = process.arch === 'arm64' ? /arm64|aarch64|universal/i : /x86_64|x64|universal/i;
                asset = (release.assets || []).find(item => item.name.endsWith('.apk') && architecture.test(item.name))
                    || (release.assets || []).find(item => item.name.endsWith('.apk') && !/arm|x86|x64/i.test(item.name));
                const newer = compareVersions(version, state.currentVersion) > 0;
                return publish({ status: newer ? asset ? 'available' : 'unsupported' : 'latest', availableVersion: version,
                    updateUrl: release.html_url || releasesUrl, lastCheckedAt: Date.now(),
                    updateSeen: store.get('LAST_SEEN_UPDATE_VERSION') === version,
                    error: !asset && newer ? 'This upstream release does not publish an Android APK' : null });
            } catch (error) {
                if (current !== generation) return status();
                return publish({ status: 'error', error: error.message, lastCheckedAt: Date.now() });
            }
        })();
        activeCheck = operation;
        operation.abort = () => controller.abort();
        try { return await operation; } finally { if (activeCheck === operation) activeCheck = null; }
    };
    const api = {
        getUpdateStatus: status, checkForUpdates: check,
        markUpdateSeen: version => { const value = version || state.availableVersion; store.set('LAST_SEEN_UPDATE_VERSION', value); return publish({ lastSeenVersion: value, updateSeen: value === state.availableVersion }); },
        openUpdateReleasePage: () => platform.electron.shell.openExternal(state.updateUrl || releasesUrl).then(() => true),
        downloadUpdate: async () => {
            if (activeDownload) return status();
            if (!asset || state.status !== 'available') throw new Error('The selected upstream release has no compatible Android APK');
            const selectedAsset = { ...asset }, current = generation;
            const controller = new AbortController();
            activeDownload = controller;
            downloaded = null;

            const target = path.join(dataDir, 'updates');
            const file = path.join(target, 'Folia-update-' + current + '.apk'), temporary = file + '.part';
            publish({ status: 'downloading', downloadProgress: { percent: 0, transferred: 0, total: selectedAsset.size } });
            try {
                await fs.promises.mkdir(target, { recursive: true });
                const response = await fetch(selectedAsset.browser_download_url, { signal: AbortSignal.any([controller.signal, AbortSignal.timeout(30 * 60 * 1000)]) });
                if (!response.ok || !response.body) throw new Error('APK download failed: HTTP ' + response.status);
                const hash = crypto.createHash('sha256'); let transferred = 0, previous = 0;
                const source = Readable.fromWeb(response.body);
                source.on('data', bytes => {
                    hash.update(bytes); transferred += bytes.length;
                    if (current === generation && Date.now() - previous > 250) { previous = Date.now(); publish({ downloadProgress: { percent: Math.min(100, transferred / selectedAsset.size * 100), transferred, total: selectedAsset.size } }); }
                });
                await pipeline(source, fs.createWriteStream(temporary, { mode: 0o600 }), { signal: controller.signal });
                if (current !== generation) throw new Error('The selected update channel changed');
                if (transferred !== selectedAsset.size) throw new Error('APK download is incomplete');
                const digest = hash.digest('hex');
                if (selectedAsset.digest && selectedAsset.digest !== 'sha256:' + digest) throw new Error('APK checksum mismatch');
                await fs.promises.rename(temporary, file); downloaded = file;
                return publish({ status: 'downloaded', downloadProgress: { percent: 100, transferred, total: selectedAsset.size } });
            } catch (error) { await fs.promises.rm(temporary, { force: true });
                return current === generation ? publish({ status: 'error', error: error.message }) : status();
            } finally { if (activeDownload === controller) activeDownload = null; }
        },
        quitAndInstallUpdate: async () => {
            if (!downloaded) throw new Error('Download an Android APK first');
            return events.native('installUpdate', downloaded);
        },
    };
    api._applyUpdateSetting = async key => {
        if (!['UPDATE_CHANNEL', 'ENABLE_UPDATE_CHECK', 'ENABLE_AUTO_UPDATE'].includes(key)) return;
        if (key !== 'ENABLE_AUTO_UPDATE') {
            generation++;
            activeCheck?.abort(); activeCheck = null;
            const download = activeDownload;
            download?.abort();
            asset = null; downloaded = null;
            publish({ status: key === 'ENABLE_UPDATE_CHECK' && !enabled(key) ? 'disabled' : channel().updateEnabled ? 'idle' : 'unsupported', availableVersion: null,
                updateUrl: releasesUrl, error: null, downloadProgress: null });
        } else publish({});
        if (enabled('ENABLE_UPDATE_CHECK') && channel().updateEnabled) {
            const result = key === 'ENABLE_AUTO_UPDATE' && state.status === 'available' ? status() : await check();
            if (result.status === 'available' && enabled('ENABLE_AUTO_UPDATE')) await api.downloadUpdate();
        }
    };
    if (enabled('ENABLE_UPDATE_CHECK')) void api._applyUpdateSetting('ENABLE_UPDATE_CHECK')
        .catch(error => console.warn('[AndroidUpdate]', error));
    return api;
};

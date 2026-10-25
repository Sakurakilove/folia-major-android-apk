require('./lifecycle.cjs')();
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const http = require('node:http');

// Android's in-process Node host reuses the desktop provider and AI implementations.
const dataDir = process.argv[2];
const token = process.env.FOLIA_RUNTIME_TOKEN || process.argv[3];
const encryptionKey = Buffer.from(process.env.FOLIA_RUNTIME_KEY || process.argv[4] || '', 'base64');
delete process.env.FOLIA_RUNTIME_TOKEN;
delete process.env.FOLIA_RUNTIME_KEY;
if (!dataDir || !token || encryptionKey.length !== 32) throw new Error('Missing native runtime configuration');
fs.mkdirSync(dataDir, { recursive: true });
process.env.TMPDIR = path.join(dataDir, 'tmp');
fs.mkdirSync(process.env.TMPDIR, { recursive: true });
process.chdir(dataDir);
globalThis.File ??= require('node:buffer').File;
const { fetch, Headers, Request, Response } = require('undici');
Object.assign(globalThis, { fetch, Headers, Request, Response });

const configPath = path.join(dataDir, 'settings.json');
let settings = fs.existsSync(configPath) ? JSON.parse(fs.readFileSync(configPath, 'utf8')) : {};
const defaults = { AI_PROVIDER: 'gemini', OPENAI_API_URL: 'https://api.openai.com/v1', OPENAI_API_MODEL: '',
    OPENAI_API_TEMPERATURE: 0.7, OPENAI_API_STREAM: false, USE_SYSTEM_PROXY_FOR_AI: false,
    ENABLE_UPDATE_CHECK: false, ENABLE_AUTO_UPDATE: false, UPDATE_CHANNEL: 'realeco',
    MOD_SYSTEM_ENABLED: false, DISCORD_RICH_PRESENCE_ENABLED: false };
settings = { ...defaults, ...settings };
const { createJsonPersistence, flushJsonPersistence } = require('./jsonPersistence.cjs');
const settingsPersistence = createJsonPersistence(configPath, () => JSON.stringify(settings));
const persist = () => settingsPersistence.schedule();
const store = { get store() { return { ...settings }; }, get: (key, fallback) => settings[key] ?? fallback,
    set: (key, value) => { settings[key] = value; persist(); },
    delete: key => { delete settings[key]; persist(); } };
const safeStorage = {
    isEncryptionAvailable: () => true,
    encryptString: text => {
        const iv = crypto.randomBytes(12);
        const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey, iv);
        const ciphertext = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
        return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
    },
    decryptString: bytes => {
        const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey, bytes.subarray(0, 12));
        decipher.setAuthTag(bytes.subarray(12, 28));
        return Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString('utf8');
    },
};
const events = require('./events.cjs')();
const network = require('./network.cjs')({ events });
globalThis.fetch = (url, options) => network.fetch(url, options, false);
const platform = require('./platform.cjs')({ dataDir, events, network });
platform.electron.safeStorage = safeStorage;
const { createAiCredentialStore, isAiCredentialKey, isReservedAiCredentialKey } = require('./electron/aiCredentialStore.cjs');
const credentials = createAiCredentialStore({ store, safeStorage, platform: 'android' });
credentials.migrate();
const { createKugouApiBridge } = require('./electron/kugou/kugouApiBridge.cjs');
const kugou = createKugouApiBridge({ store, safeStorage, platform: 'android' });
const { createBodianApiBridge } = require('./electron/bodian/bodianApiBridge.cjs');
const bodian = createBodianApiBridge({ store, safeStorage });
const { createQqBackend } = require('./electron/qq/qqBackend.cjs');
const { createQqAuthSessionRepository } = require('./electron/qq/qqAuthSessionRepository.cjs');
const { createNeteaseBackend } = require('./electron/netease/neteaseBackend.cjs');
const broadcast = (channel, ...args) => events.emit(channel, ...args);
const netease = createNeteaseBackend({ broadcast, onUnhandledRejection: error => console.warn('[AndroidNetease]', error) });
const qq = createQqBackend({ broadcast, getStateFilePath: () => path.join(dataDir, 'qq-device.json'),
    authSessionRepository: createQqAuthSessionRepository({ store, safeStorage, platform: 'android' }) });

require('./electron/loginBackendIpc.cjs').registerLoginBackendIpc({ ipcMain: platform.ipcMain, app: platform.app, safeStorage,
    neteaseBackend: netease, qqBackend: qq, getDefaultSession: () => ({ resolveProxy: network.resolveProxy }) });
const ai = require('./ai.cjs')({ store: credentials.settingsView, credentials, network });
const cacheDirectory = path.join(dataDir, 'cache');
fs.mkdirSync(cacheDirectory, { recursive: true });
const configuredCache = () => store.get('CACHE_DIRECTORY', cacheDirectory);
const cacheState = () => ({ path: configuredCache(), defaultPath: cacheDirectory, isCustom: configuredCache() !== cacheDirectory, isDefault: configuredCache() === cacheDirectory });
const publicSettings = require('./generated/publicSettings.cjs')({ store, aiCredentials: credentials, app: platform.app });
store.getBoolean = publicSettings.readStoredBoolean;
const unsupportedSettings = new Set(['DISCORD_RICH_PRESENCE_ENABLED']);
const normalizeSavedSetting = require('./generated/normalizeSettings.cjs');
const neteasePortWhenNeeded = require('./lazyBackend.cjs')(netease);
const qqPortWhenNeeded = require('./lazyBackend.cjs')(qq);
const handlers = {
    ...require('./analysis.cjs')({ dataDir, store, events }),
    _poll: (cursor, windowId = 1) => ({ ...events.read(cursor, windowId), action: windowId === 1 && process.env.FOLIA_NATIVE_DISPATCHER !== 'true' ? events.nextNative() : null }),
    _waitEvents: async (cursor, windowId = 1) => ({ ...await events.waitEvents(cursor, windowId), action: null }),
    _nativePoll: () => events.waitNative(),
    _completeNative: (id, value, error) => events.completeNative(id, value, error),
    _send: (channel, ...args) => platform.invoke(channel, args),
    getSettings: publicSettings,
    _syncWallpaperState: active => { if (store.get('wallpaper_mode',false) !== Boolean(active)) { store.set('wallpaper_mode',Boolean(active)); events.emit('wallpaper-mode-changed',Boolean(active)); } return Boolean(active); },
    saveSettings: async (key, value) => {
        if (typeof key !== 'string' || key.length > 150 || key === 'DISCORD_RICH_PRESENCE_APPLICATION_ID' || isReservedAiCredentialKey(key)) return publicSettings();
        if (isAiCredentialKey(key) && typeof value !== 'string') return publicSettings();
        const normalized = normalizeSavedSetting(key,value);
        if (!normalized.accepted) return publicSettings();
        value = normalized.value;
        if (unsupportedSettings.has(key) && value === true) throw new Error('This desktop integration has not been ported to Android');
        if (key === 'wallpaper_mode') value = await events.native('wallpaperMode', Boolean(value));
        const previous = settings[key], existed = Object.hasOwn(settings,key);
        if (isAiCredentialKey(key)) credentials.set(key, value);
        else store.set(key, value);
        try { await subsystems?.settingChanged(key); }
        catch (error) { if (!isAiCredentialKey(key)) { if (existed) store.set(key,previous); else store.delete(key); } throw error; }
        if (key === 'wallpaper_mode') events.emit('wallpaper-mode-changed', Boolean(value));
        return publicSettings();
    },
    getNeteasePort: neteasePortWhenNeeded,
    getNeteaseApiStatus: () => netease.getStatus(),
    getQqPort: qqPortWhenNeeded,
    getQqApiStatus: () => qq.getStatus(),
    restartNeteaseApi: reason => netease.start(reason),
    getKugouApiStatus: () => kugou.getStatus(),
    kugouRequest: (operation, params) => kugou.request(operation, params),
    bodianRequest: (operation, params) => bodian.request(operation, params),
    getCacheDirectory: cacheState,
    resetCacheDirectory: () => { store.delete('CACHE_DIRECTORY'); return cacheState(); },
    chooseCacheDirectory: async () => {
        const selection = await events.native('openDialog', { properties: ['openDirectory', 'createDirectory'] });
        if (selection.canceled) return { ...cacheState(), canceled: true };
        const selected = selection.filePaths[0];
        await fs.promises.access(selected, fs.constants.R_OK | fs.constants.W_OK);
        store.set('CACHE_DIRECTORY', selected);
        return { ...cacheState(), canceled: false };
    },
    setAppLocale: locale => { store.set('APP_LOCALE', locale); return locale; },
    generateTheme: ai.generateTheme,
    segmentLyrics: ai.segmentLyrics,
    testAiConnection: ai.testAiConnection,
    ...require('./generated/lyrics.cjs'),
};
let subsystems;
const apiSpec = require('./shared/androidApiSpec.json');
handlers._capabilities = () => [...new Set([...Object.keys(handlers).filter(name => name !== '_waitEvents' || process.env.FOLIA_NATIVE_DISPATCHER === 'true'), ...Object.entries(apiSpec)
    .filter(([, spec]) => (platform.handlers.has(spec.channel || spec.send) || platform.ipcMain.listenerCount(spec.channel || spec.send))).map(([name]) => name)])];
handlers.installAndroidModZip = async (name, bytes) => {
    if (!name?.toLowerCase().endsWith('.zip')) throw new Error('A ZIP archive is required');
    const file = path.join(process.env.TMPDIR, crypto.randomUUID() + '.zip');
    await fs.promises.writeFile(file, Buffer.from(bytes));
    try { return await platform.invoke(apiSpec['mods.installModFromZip'].channel, [file]); }
    finally { await fs.promises.rm(file, { force: true }); }
};
const wire = require('./wire.cjs')(path.join(dataDir, 'bridge-binary'));

const startup = require('./subsystems.cjs')({ platform, store, events, safeStorage, netease, dataDir, network, getConfiguredCacheDirectory: configuredCache }).then(result => {
    subsystems = result; Object.assign(handlers, result.handlers);
});

const server = http.createServer(async (req, res) => {
    // The renderer talks through the native plugin: the bearer never enters WebView JavaScript.
    if (req.headers.authorization !== 'Bearer ' + token) { res.writeHead(403); return res.end('{}'); }
    try {
        if (req.method === 'GET' && req.url.startsWith('/protocol?')) {
            const url = new URL(req.url, 'http://127.0.0.1');
            const target = new URL(url.searchParams.get('url'));
            const handler = platform.protocols.get(target.protocol.slice(0, -1));
            if (!handler) throw new Error('Unregistered Android media protocol');
            const response = await handler(new Request(target, { headers: req.headers }));
            res.statusCode = response.status;
            response.headers.forEach((value, key) => res.setHeader(key, value));
            res.setHeader('Access-Control-Allow-Origin', '*');
            if (!response.body) return res.end();
            const source = require('node:stream').Readable.fromWeb(response.body);
            res.on('close', () => source.destroy());
            source.on('error', () => res.destroy());
            source.pipe(res);
            return;
        }
        res.setHeader('Content-Type', 'application/json');
        if (req.method !== 'POST' || req.url !== '/rpc') throw new Error('Invalid runtime route');
        let size = 0;
        const chunks = [];
        for await (const chunk of req) {
            size += chunk.length;
            if (size > 8 * 1024 * 1024) throw new Error('Request too large');
            chunks.push(chunk);
        }
        const { method, args, windowId = 1 } = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        if (!Array.isArray(args)) throw new Error('Invalid Android method arguments');
        const decoded = await wire.decode(args);
        const result = await platform.context.run({ windowId }, () => Object.hasOwn(handlers, method) ? handlers[method](...decoded)
            : platform.invoke(apiSpec[method]?.channel || apiSpec[method]?.send, decoded, windowId));
        await flushJsonPersistence();
        res.end(JSON.stringify({ ok: true, result: await wire.encode(platform.rewrite(result ?? null)) }));
    } catch (error) {
        res.statusCode = 400;
        res.end(JSON.stringify({ ok: false, error: error.message }));
    }
});
startup.then(() => server.listen(0, '127.0.0.1', () => {
    const readyPath = path.join(dataDir, 'ready.json');
    fs.writeFileSync(readyPath + '.tmp', JSON.stringify({ port: server.address().port }), { mode: 0o600 });
    fs.renameSync(readyPath + '.tmp', readyPath);
    console.log('[AndroidRuntime] RPC ready');
})).catch(error => { console.error('[AndroidRuntime] Startup failed', error); process.exitCode = 1; });

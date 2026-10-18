const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const { EventEmitter } = require('node:events');
const { Readable } = require('node:stream');

// Supply the real Android storage, IPC and protocol boundaries needed by portable desktop subsystems.
module.exports = ({ dataDir, events, network }) => {
    const context = new (require('node:async_hooks').AsyncLocalStorage)();
    const ipcMain = new EventEmitter();
    const handlers = new Map();
    ipcMain.handle = (channel, handler) => {
        if (handlers.has(channel)) throw new Error('Duplicate Android IPC handler: ' + channel);
        handlers.set(channel, handler);
    };
    ipcMain.removeHandler = channel => handlers.delete(channel);
    const protocols = new Map();
    const protocol = { handle: (scheme, handler) => { protocols.set(scheme, handler); },
        unhandle: scheme => protocols.delete(scheme), isProtocolHandled: scheme => protocols.has(scheme) };
    const app = new EventEmitter();
    let rendererMetrics = null, rendererReportedAt = 0, nativeMetrics = null, nativeReportedAt = 0, nativePending = false, nativeCPU = 0;
    const refreshNativeMetrics = () => {
        if(nativePending)return;nativePending=true;
        void events.native('appProcessMemory').then(report=>{
            if(nativeMetrics && report.elapsedMs>nativeMetrics.elapsedMs)
                nativeCPU=Math.max(0,(report.cpuMs-nativeMetrics.cpuMs)/(report.elapsedMs-nativeMetrics.elapsedMs)*100);
            nativeMetrics=report;nativeReportedAt=Date.now();
        }).catch(error=>console.warn('[AndroidMemory] Native process measurement unavailable',error)).finally(()=>{nativePending=false;});
    };
    const processMetrics = require('./processMetrics.cjs')();
    const recordRendererMetrics = report => { rendererMetrics=report;rendererReportedAt=Date.now(); };
    const rendererIsCurrent = () => rendererMetrics && Date.now()-rendererReportedAt < 30000;
    Object.assign(app, {
        isPackaged: true,
        rewriteAndroidProtocolUrls: value => rewrite(value),
        publishAndroidExport: file => events.native('publishExport', file),
        getVersion: () => process.env.FOLIA_APP_VERSION || require('./package.json').version,
        getAppPath: () => __dirname,
        getName: () => 'Folia',
        getPath: name => {
            const directory = ['userData', 'appData'].includes(name) ? dataDir : path.join(dataDir, name);
            fs.mkdirSync(directory, { recursive: true });
            return directory;
        },
        whenReady: () => Promise.resolve(), isReady: () => true,
        getLocale: () => process.env.FOLIA_LOCALE || Intl.DateTimeFormat().resolvedOptions().locale,
        getAppMetrics: () => {
            refreshNativeMetrics();
            const nativeRows=nativeMetrics && Date.now()-nativeReportedAt<30000 && typeof nativeMetrics.residentKB==='number'
                ? [{pid:nativeMetrics.pid,type:'Browser',name:'Android Java / WebView host',
                    memory:{workingSetSize:nativeMetrics.residentKB,peakWorkingSetSize:nativeMetrics.peakResidentKB,privateBytes:nativeMetrics.privateKB},
                    cpu:{percentCPUUsage:nativeCPU,cumulativeCPUUsage:nativeMetrics.cpuMs/1000}}] : [];
            return [...processMetrics(),...nativeRows, ...(rendererIsCurrent() && typeof rendererMetrics.residentKB === 'number'
            ? [{pid:rendererMetrics.pid,type:'Tab',name:'Android main WebView',memory:{workingSetSize:rendererMetrics.residentKB}}] : [])];
        },
    });
    const mainWindow = new EventEmitter();
    const webContents = new EventEmitter();
    Object.assign(webContents, { id: 1, send: (channel, ...args) => events.emit(channel, ...args), isDestroyed: () => false,
        executeJavaScript: async code => { const result = await events.native('windowEvaluate', 1, code); if (result.error) throw new Error(result.error); return result.value; },
        getURL: () => 'https://localhost/', getOSProcessId: () => rendererIsCurrent() ? rendererMetrics.pid : 0, isCrashed: () => Boolean(webContents.crashed) });
    Object.assign(mainWindow, { id: 1, webContents, isDestroyed: () => false });
    const dialog = {
        showMessageBox: (...args) => events.native('messageBox', args.at(-1)),
        showOpenDialog: (...args) => events.native('openDialog', args.at(-1)),
        showSaveDialog: (...args) => events.native('saveDialog', args.at(-1)),
    };
    const shell = {
        openExternal: url => events.native('openExternal', url),
        openPath: file => events.native('openPath', file),
        showItemInFolder: file => events.native('openPath', file),
    };
    class Store {
        constructor(options = {}) {
            this.path = path.join(dataDir, (options.name || 'config') + '.json');
            this.defaults = options.defaults || {};
            this.listeners = new EventEmitter();
            this.values = { ...this.defaults, ...(fs.existsSync(this.path) ? JSON.parse(fs.readFileSync(this.path, 'utf8')) : {}) };
        }
        get store() { return structuredClone(this.values); }
        set store(value) { this.values = { ...value }; this.persist(); }
        get(key, fallback) { return this.values[key] ?? fallback; }
        has(key) { return Object.hasOwn(this.values, key); }
        set(key, value) {
            if (typeof key === 'object') { for (const [name, item] of Object.entries(key)) this.set(name, item); return; }
            const previous = this.values[key];
            this.values[key] = value;
            this.persist();
            this.listeners.emit(key, value, previous);
            this.listeners.emit('*', this.store);
        }
        delete(key) { delete this.values[key]; this.persist(); }
        clear() { this.values = { ...this.defaults }; this.persist(); }
        persist() { fs.writeFileSync(this.path + '.tmp', JSON.stringify(this.values), { mode: 0o600 }); fs.renameSync(this.path + '.tmp', this.path); }
        onDidChange(key, listener) { this.listeners.on(key, listener); return () => this.listeners.off(key, listener); }
        onDidAnyChange(listener) { return this.onDidChange('*', listener); }
    }
    Store.default = Store;
    const net = { fetch: async (input, options) => {
        const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
        if (url.startsWith('file:')) return new Response(Readable.toWeb(fs.createReadStream(require('node:url').fileURLToPath(url))));
        return network.fetch(input, options, true);
    } };
    const BrowserWindow = require('./windows.cjs')({ events, mainWindow, dataDir });
    const electron = { app, ipcMain, protocol, dialog, shell, net, BrowserWindow };
    Object.assign(mainWindow, {
        isFullScreen: () => Boolean(mainWindow.fullscreen),
        setFullScreen: active => events.native('windowFullscreen', 1, active).then(() => { mainWindow.fullscreen = active; }),
        minimize: () => events.native('windowHide', 1), close: () => events.native('windowClose', 1),
    });
    const previousLoad = Module._load;
    Module._load = function(name, parent, isMain) {
        if (name === 'electron') return electron;
        if (name === 'electron-store') return Store;
        return previousLoad.apply(this, arguments);
    };
    const schemes = new Set(['folia-mod', 'folia-cover', 'folia-transcode', 'folia-ytm', 'folia-spotify']);
    const rewrite = value => {
        if (typeof value === 'string') {
            const match = /^(folia-[a-z-]+):\/\/([^/]+)(.*)$/.exec(value);
            if (match && schemes.has(match[1])) return 'https://' + match[2] + '.' + match[1] + '.localhost' + match[3];
            return value;
        }
        if (!value || typeof value !== 'object' || ArrayBuffer.isView(value) || value instanceof ArrayBuffer) return value;
        if (Array.isArray(value)) return value.map(rewrite);
        return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, rewrite(item)]));
    };
    return { context, app, mainWindow, recordRendererMetrics, electron, ipcMain, handlers, protocols, protocol, net, rewrite,
        event: { sender: webContents },
        invoke: (channel, args, windowId = 1) => {
            const sender = BrowserWindow.fromId(windowId)?.webContents;
            if (!sender) throw new Error("Unknown Android renderer");
            const handler = handlers.get(channel);
            if (handler) return handler({ sender }, ...args);
            if (ipcMain.listenerCount(channel)) { ipcMain.emit(channel, { sender }, ...args); return null; }
            throw new Error('Android subsystem is not registered: ' + channel);
        },
    };
};

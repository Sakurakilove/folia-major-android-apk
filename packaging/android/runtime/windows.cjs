const fs = require('node:fs');
const path = require('node:path');
const { EventEmitter } = require('node:events');

module.exports = ({ events, mainWindow, dataDir }) => {
    let sequence = 1;
    const windows = new Map([[1, mainWindow]]);
    class AndroidWindow extends EventEmitter {
        constructor(options = {}) {
            super();
            this.id = ++sequence;
            if (options.x <= -10000 || options.y <= -10000) options = { ...options, show: false };
            this.options = options; this.destroyed = false;
            this.bounds = { x: options.x || 0, y: options.y || 0, width: options.width || 1280, height: options.height || 720 };
            this.ready = events.native('windowCreate', this.id, options);
            this.webContents = new EventEmitter();
            Object.assign(this.webContents, {
                id: this.id, send: (channel, ...args) => events.target(this.id, channel, ...args),
                isDestroyed: () => this.destroyed, isCrashed: () => Boolean(this.webContents.crashed), getURL: () => this.url || '', getOSProcessId: () => 0,
                executeJavaScript: async code => {
                    await this.ready;
                    const answer = await events.native('windowEvaluate', this.id, code);
                    if (answer.error) throw new Error(answer.error);
                    return answer.value;
                },
                capturePage: async () => {
                    await this.ready;
                    const image = await events.native('windowCapture', this.id);
                    const png = fs.readFileSync(image.png), raw = fs.readFileSync(image.raw);
                    fs.rmSync(image.png); fs.rmSync(image.raw);
                    return { isEmpty: () => !png.length, getSize: () => ({ width: image.width, height: image.height }),
                        toPNG: () => png, toBitmap: () => raw, getBitmap: () => raw };
                },
                setWindowOpenHandler: handler => { this.openHandler = handler; },
                setBackgroundThrottling: () => { /* Virtual displays continue compositing independently of activity visibility. */ },
            });
            windows.set(this.id, this);
            this.ready.catch(error => {
                // A refused Android window must reject its caller without terminating the playback backend.
                if (this.listenerCount('error')) this.emit('error', error);
                else console.warn('[AndroidWindow] Native window creation failed', error);
            });
        }
        async loadFile(file, options = {}) {
            await this.ready;
            this.url = require('node:url').pathToFileURL(file).href;
            let html = fs.readFileSync(file, 'utf8');
            if (this.options.privileged === true) {
                // Defer original inline desktop scripts until the Android preload facade is installed.
                html = html.replace(/<script(?![^>]*\btype=["']module["'])([^>]*)>/gi, '<script type="application/folia-deferred"$1>');
                html = html.replace('</head>', '<script type="module" src="/assets/android-secondary-bridge.js"></script></head>');
            }
            await events.native('windowLoad', this.id, html, options.query || {});
            this.webContents.emit('did-finish-load'); this.emit('ready-to-show');
        }
        async loadURL(url) {
            if (url.startsWith('file:')) return this.loadFile(require('node:url').fileURLToPath(url));
            throw new Error('Privileged auxiliary windows accept bundled local documents only');
        }
        isDestroyed() { return this.destroyed; }
        getBounds() { return { ...this.bounds }; }
        getContentBounds() { return this.getBounds(); }
        getContentSize() { return [this.bounds.width, this.bounds.height]; }
        setBounds(bounds) { this.bounds = { ...this.bounds, ...bounds }; return this.command('windowBounds', this.bounds); }
        setContentSize(width, height) { return this.setBounds({ width, height }); }
        setSize(width, height) { return this.setContentSize(width, height); }
        command(method, ...args) { return this.ready.then(() => events.native(method, this.id, ...args)); }
        show() { this.visible = true; return this.command('windowShow'); }
        showInactive() { return this.show(); }
        hide() { this.visible = false; return this.command('windowHide'); }
        isVisible() { return this.visible ?? this.options.show !== false; }
        focus() { return this.show(); }
        setAlwaysOnTop(value) { this.top = value; return this.command('windowTop', value); }
        isAlwaysOnTop() { return Boolean(this.top); }
        setSkipTaskbar(value) { return this.command('windowSkipTaskbar',value); }
        setTitlebarVisible(value) { return this.command('windowTitlebar', value); }
        setIgnoreMouseEvents(value) { return this.command('windowClickThrough', value); }
        setFullScreen(value) { this.fullscreen = value; return this.command('windowFullscreen', value); }
        isFullScreen() { return Boolean(this.fullscreen); }
        close() { return this.destroy(); }
        destroy() {
            if (this.destroyed) return;
            this.destroyed = true; windows.delete(this.id);
            this.command('windowClose').catch(error => console.warn('[AndroidWindow]', error)); this.emit('closed');
        }
        nativeClosed() {
            if (this.destroyed) return;
            this.destroyed = true; windows.delete(this.id); this.emit('closed');
        }
        static getAllWindows() { return [...windows.values()]; }
        static fromWebContents(contents) { return [...windows.values()].find(window => window.webContents === contents); }
        static fromId(id) { return windows.get(id); }
    }
    return AndroidWindow;
};

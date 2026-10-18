const http = require('node:http');
const net = require('node:net');
const WebSocket = require('ws');
const { EventEmitter } = require('node:events');

// Android WebView exposes the same DOM/CSS inspection protocol as the desktop renderer, over an app-local socket.
module.exports = ({ events, mainWindow, recordRendererMetrics = () => {} }) => {
    let pending = Promise.resolve(), exportClient = null, exportDpr = 1;
    const connect = async pid => {
        const socketPath = '\0webview_devtools_remote_' + pid;
        const targets = await new Promise((resolve, reject) => {
            const request = http.get({ socketPath, path: '/json/list', headers: { Host: 'localhost' }, timeout: 10000 }, response => {
                const chunks = []; response.on('data', chunk => chunks.push(chunk));
                response.on('end', () => { try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch (error) { reject(error); } });
            });
            request.on('error', reject); request.on('timeout', () => request.destroy(new Error('WebView inspection timed out')));
        });
        for (const target of targets) {
            if (!target.webSocketDebuggerUrl) continue;
            const websocket = new WebSocket(target.webSocketDebuggerUrl, { createConnection: () => net.connect(socketPath), handshakeTimeout: 10000 });
            await new Promise((resolve, reject) => { websocket.once('open', resolve); websocket.once('error', reject); });
            const replies = new Map(), protocolEvents = new EventEmitter(); let sequence = 0;
            websocket.on('message', bytes => {
                const message = JSON.parse(bytes.toString());
                if (message.method) { protocolEvents.emit('event',message.method,message.params || {}); return; }
                const reply = replies.get(message.id);
                if (!reply) return; replies.delete(message.id); clearTimeout(reply.timer);
                if (message.error) reply.reject(new Error(message.error.message)); else reply.resolve(message.result);
            });
            websocket.on('error', error => { for (const reply of replies.values()) { clearTimeout(reply.timer); reply.reject(error); } replies.clear(); });
            websocket.on('close', () => { for (const reply of replies.values()) { clearTimeout(reply.timer); reply.reject(new Error('WebView inspection closed')); } replies.clear(); });
            const send = (method, params = {}) => new Promise((resolve, reject) => {
                const id = ++sequence;
                const timer = setTimeout(() => { replies.delete(id); reject(new Error('WebView inspection command timed out: ' + method)); }, 10000);
                replies.set(id, { resolve, reject, timer }); websocket.send(JSON.stringify({ id, method, params }));
            });
            try {
                const identity = await send('Runtime.evaluate', { expression: 'window.__foliaAndroidWindowId', returnByValue: true });
                if (identity.result?.value === 1) return { send, close: () => websocket.close(),
                    onEvent: listener => { protocolEvents.on('event',listener);return () => protocolEvents.off('event',listener); } };
            } catch (error) { websocket.close(); throw error; }
            websocket.close();
        }
        throw new Error('The main Android renderer is not available for inspection');
    };
    const inspectFonts = selector => {
        const result = pending.then(async () => {
            const { pid } = await events.native('webDebug', true);
            let client;
            try {
                client = exportClient || await connect(pid);
                const debuggerAdapter = { isAttached: () => true, sendCommand: (...args) => client.send(...args) };
                return await require('./generated/fonts.cjs')({ mainWindow: { ...mainWindow, webContents: { ...mainWindow.webContents, debugger: debuggerAdapter } } })(selector);
            } finally { if (client !== exportClient) client?.close(); if (!exportClient) await events.native('webDebug', false); }
        });
        pending = result.catch(() => {}); return result;
    };
    const serialize = action => {
        const result = pending.then(action); pending = result.catch(() => {}); return result;
    };
    inspectFonts.memory = () => serialize(async () => {
        let client;
        try {
            const { pid } = await events.native('webDebug',true);
            client=exportClient || await connect(pid);
            const report=await require('./rendererMemory.cjs')(client);
            if(report)recordRendererMetrics(report);
            return report;
        } catch(error){console.warn('[AndroidMemory] Renderer inspection failed',error);return null;}
        finally {if(client!==exportClient)client?.close();if(!exportClient)await events.native('webDebug',false).catch(error=>console.warn('[AndroidMemory] Cannot close inspector',error));}
    });
    inspectFonts.reportDevicePixelRatio = ratio => {
        if (!exportClient && Number.isFinite(Number(ratio)) && Number(ratio) > 0) exportDpr = Number(ratio);
        return true;
    };
    inspectFonts.prepareVideoExportWindow = size => serialize(async () => {
        const width = Math.round(Number(size?.width)), height = Math.round(Number(size?.height));
        if (!Number.isFinite(width) || !Number.isFinite(height) || width < 320 || height < 320) return false;
        const reportedDpr = Number(size?.dpr);
        if (Number.isFinite(reportedDpr) && reportedDpr > 0) exportDpr = reportedDpr;
        if (!exportClient) {
            const { pid } = await events.native('webDebug', true);
            try { exportClient = await connect(pid); }
            catch (error) { await events.native('webDebug', false); throw error; }
        }
        try {
            await exportClient.send('Emulation.setDeviceMetricsOverride', {
                width: Math.max(1, Math.round(Math.min(width, 3840) / exportDpr)),
                height: Math.max(1, Math.round(Math.min(height, 3840) / exportDpr)),
                deviceScaleFactor: exportDpr, mobile: false, dontSetVisibleSize: false,
            });
            return { success: true, dpr: exportDpr };
        } catch (error) {
            try { await exportClient.send('Emulation.clearDeviceMetricsOverride'); }
            finally { exportClient.close(); exportClient = null; await events.native('webDebug', false); }
            throw error;
        }
    });
    inspectFonts.restoreVideoExportWindow = () => serialize(async () => {
        if (!exportClient) return false;
        try { await exportClient.send('Emulation.clearDeviceMetricsOverride'); return true; }
        finally { exportClient.close(); exportClient = null; await events.native('webDebug', false); }
    });
    return inspectFonts;
};

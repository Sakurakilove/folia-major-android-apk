import { afterEach, describe, expect, it } from 'vitest';
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
const require = createRequire(import.meta.url);
const { WebSocketServer } = require('ws');
const createRenderer = require('../../../packaging/android/runtime/debugger.cjs');

// Exercise the actual app-local CDP transport and export lifetime against a protocol peer.
const cleanup: Array<() => Promise<void>> = [];
afterEach(async () => { for (const close of cleanup.splice(0)) await close(); });
const protocolPeer = async (failFirstResize = false) => {
    const pid = 'folia-test-' + randomUUID();
    const commands: Array<{ method: string; params: Record<string, unknown> }> = [];
    const server = createServer((_request, response) => {
        response.setHeader('Content-Type', 'application/json');
        response.end(JSON.stringify([{ webSocketDebuggerUrl: 'ws://localhost/devtools/page/1' }]));
    });
    const websocket = new WebSocketServer({ noServer: true });
    server.on('upgrade', (request, socket, head) => websocket.handleUpgrade(request, socket, head, (connection: unknown) => websocket.emit('connection', connection)));
    websocket.on('connection', (connection: { on: Function; send: Function }) => connection.on('message', (bytes: Buffer) => {
        const command = JSON.parse(bytes.toString()); commands.push(command);
        const failed = failFirstResize && command.method === 'Emulation.setDeviceMetricsOverride';
        if (failed) failFirstResize = false;
        if (command.method === 'Runtime.evaluate' && command.params.expression.startsWith('console.timeStamp(')) {
            const marker = JSON.parse(command.params.expression.slice('console.timeStamp('.length,-1));
            connection.send(JSON.stringify({method:'Tracing.dataCollected',params:{value:[{name:'TimeStamp',pid:482,args:{data:{message:marker}}}]}}));
        }
        if (command.method === 'Tracing.end') {
            connection.send(JSON.stringify({method:'Tracing.dataCollected',params:{value:[{name:'periodic_interval',pid:482,args:{dumps:{
                process_totals:{resident_set_bytes:'100000',private_footprint_bytes:'80000'},
                allocators:{blink_gc:{attrs:{size:{value:'40000'}}}},
            }}}]}}));
            connection.send(JSON.stringify({method:'Tracing.tracingComplete',params:{}}));
        }
        connection.send(JSON.stringify({ id: command.id, ...(failed ? { error: { message: 'The renderer rejected the requested size' } }
            : { result: command.method === 'Runtime.evaluate' ? { result: { value: 1 } } : {} }) }));
    }));
    await new Promise<void>((resolve, reject) => { server.once('error', reject); server.listen('\0webview_devtools_remote_' + pid, resolve); });
    cleanup.push(async () => {
        for (const connection of websocket.clients) connection.terminate();
        await new Promise<void>(resolve => server.close(() => resolve()));
        websocket.close();
    });
    const debugSwitches: boolean[] = [];
    const memoryReports: unknown[] = [];
    const renderer = createRenderer({ mainWindow: { webContents: {} }, recordRendererMetrics: (report: unknown) => memoryReports.push(report), events: { native: async (method: string, enabled: boolean) => {
        expect(method).toBe('webDebug'); debugSwitches.push(enabled); return { pid };
    } } });
    return { renderer, commands, debugSwitches, memoryReports };
};

describe('Android renderer export sizing', () => {
    it('uses the target renderer trace PID and real dump units for memory reports', async () => {
        const { renderer, memoryReports, debugSwitches } = await protocolPeer();
        expect(await renderer.memory()).toEqual({pid:482,residentKB:1024,privateKB:512,blinkAllocatedKB:256});
        expect(memoryReports).toEqual([{pid:482,residentKB:1024,privateKB:512,blinkAllocatedKB:256}]);
        expect(debugSwitches).toEqual([true,false]);
    });
    it('keeps the same inspector connection until restore and uses the reported physical pixel ratio', async () => {
        const { renderer, commands, debugSwitches } = await protocolPeer();
        expect(await renderer.prepareVideoExportWindow({ width: 1920, height: 1080, dpr: 2 })).toEqual({ success: true, dpr: 2 });
        renderer.reportDevicePixelRatio(3);
        expect(await renderer.prepareVideoExportWindow({ width: 1920, height: 1080 })).toEqual({ success: true, dpr: 2 });
        const sizes = commands.filter(command => command.method === 'Emulation.setDeviceMetricsOverride');
        expect(sizes.map(command => [command.params.width, command.params.height, command.params.deviceScaleFactor])).toEqual([[960, 540, 2], [960, 540, 2]]);
        expect(debugSwitches).toEqual([true]);
        expect(await renderer.restoreVideoExportWindow()).toBe(true);
        expect(commands.at(-1)?.method).toBe('Emulation.clearDeviceMetricsOverride');
        expect(debugSwitches).toEqual([true, false]);
        expect(await renderer.restoreVideoExportWindow()).toBe(false);
    });
    it('rejects invalid sizes and cleans up the inspection session when resizing fails', async () => {
        const { renderer, debugSwitches } = await protocolPeer(true);
        expect(await renderer.prepareVideoExportWindow({ width: 0, height: 1080 })).toBe(false);
        expect(debugSwitches).toEqual([]);
        await expect(renderer.prepareVideoExportWindow({ width: 1920, height: 1080, dpr: 2 })).rejects.toThrow('renderer rejected');
        expect(debugSwitches).toEqual([true, false]);
        expect(await renderer.restoreVideoExportWindow()).toBe(false);
        expect(await renderer.prepareVideoExportWindow({ width: 1920, height: 1080, dpr: 2 })).toEqual({ success: true, dpr: 2 });
        expect(await renderer.restoreVideoExportWindow()).toBe(true);
    });
});

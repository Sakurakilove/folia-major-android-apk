import { describe, expect, it } from 'vitest';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { requiresLocalNetwork } = require('../../../packaging/android/runtime/localNetwork.cjs');
const createNetwork = require('../../../packaging/android/runtime/network.cjs');

// Request Android 17 LAN permission for actual local destinations, without blocking loopback APIs or cancellation.
describe('Android local network access', () => {
    it('distinguishes loopback and public services from local IPv4, IPv6 and mDNS endpoints', () => {
        for (const host of ['localhost', 'localhost.', 'asset.folia-cover.localhost', '127.0.0.1', '127.2.3.4', '[::1]', '[::ffff:7f00:1]', '8.8.8.8', 'api.openai.com', '2001:4860:4860::8888']) expect(requiresLocalNetwork(host), host).toBe(false);
        for (const host of ['192.168.1.2', '10.0.2.2', '172.16.1.1', '172.31.255.254', '169.254.1.2', 'nas.local', 'nas.lan', '[fd00::1234]', '[fe80::1]', '[::ffff:c0a8:102]']) expect(requiresLocalNetwork(host), host).toBe(true);
        expect(requiresLocalNetwork('172.32.0.1')).toBe(false);
    });
    it('honors request cancellation while the system permission dialog is still pending', async () => {
        let finish!: (value: boolean) => void;
        const network = createNetwork({ events: { native: () => new Promise(resolve => { finish = resolve; }) } });
        const abort = new AbortController();
        const request = network.fetch('http://192.168.1.1/', { signal: abort.signal });
        const rejected = expect(request).rejects.toThrow('Cancelled by the caller');
        abort.abort(new Error('Cancelled by the caller'));
        await rejected; finish(false);
    });
});

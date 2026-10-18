const { Agent, ProxyAgent, fetch } = require('undici');
const tls = require('node:tls');
const { requiresLocalNetwork } = require('./localNetwork.cjs');
module.exports = ({ events }) => {
    const agents = new Map();
    let permissionRequest = null;
    const allowLocalNetwork = () => {
        if (!permissionRequest) permissionRequest = events.native('localNetworkPermission').then(granted => { if (granted !== true) throw new Error('Android local network permission was not granted'); return true; }).finally(() => { permissionRequest = null; });
        return permissionRequest;
    };
    const withSignal = (promise, signal) => {
        if (!signal) return promise;
        if (signal.aborted) { promise.catch(() => {}); return Promise.reject(signal.reason); }
        return new Promise((resolve, reject) => {
            const abort = () => reject(signal.reason);
            signal.addEventListener('abort', abort, { once: true });
            promise.then(value => { signal.removeEventListener('abort', abort); resolve(value); },
                error => { signal.removeEventListener('abort', abort); reject(error); });
        });
    };
    const resolve = async url => events.native('resolveProxy', String(url));
    const dispatcher = route => {
        if (!route || route.type === 'DIRECT') return undefined;
        const key = route.type + '://' + route.host + ':' + route.port;
        if (agents.has(key)) return agents.get(key);
        let agent;
        if (route.type === 'HTTP') agent = new ProxyAgent({ uri: 'http://' + route.host + ':' + route.port });
        else if (route.type === 'SOCKS') agent = new Agent({ connect: async (options, callback) => {
            try {
                const { socket } = await require('socks').SocksClient.createConnection({ proxy: { host: route.host, port: route.port, type: 5 },
                    command: 'connect', destination: { host: options.hostname, port: Number(options.port) || (options.protocol === 'https:' ? 443 : 80) }, timeout: 30000 });
                if (options.protocol !== 'https:') { callback(null, socket); return; }
                const secure = tls.connect({ socket, servername: options.servername || options.hostname, ALPNProtocols: ['http/1.1'] });
                let answered = false;
                secure.once('secureConnect', () => { if (!answered) { answered = true; callback(null, secure); } });
                secure.once('error', error => { if (!answered) { answered = true; callback(error, null); } });
            } catch (error) { callback(error, null); }
        } });
        else throw new Error('Unsupported Android proxy type');
        agents.set(key, agent); return agent;
    };
    return { resolve,
        resolveProxy: async url => { const route = await resolve(url); return route?.type === 'DIRECT' ? 'DIRECT' : (route.type === 'HTTP' ? 'PROXY ' : 'SOCKS5 ') + route.host + ':' + route.port; },
        fetch: async (url, options, useSystemProxy = false) => {
            const target = new URL(typeof url === 'string' || url instanceof URL ? String(url) : url.url);
            const signal = options && 'signal' in options ? options.signal : url?.signal;
            signal?.throwIfAborted();
            const route = useSystemProxy ? await withSignal(resolve(target.href), signal) : null;
            if (requiresLocalNetwork(target.hostname) || route && requiresLocalNetwork(route.host)) await withSignal(allowLocalNetwork(), signal);
            const requestOptions = { ...options, ...(useSystemProxy ? { dispatcher: dispatcher(route) } : {}) };
            try { return await fetch(url, requestOptions); }
            catch (error) {
                const cause = error.cause || error;
                if (!['EACCES', 'EPERM'].includes(cause.code) || !cause.address || !requiresLocalNetwork(cause.address)) throw error;
                await withSignal(allowLocalNetwork(), signal); return fetch(url, requestOptions);
            }
        },
    };
};

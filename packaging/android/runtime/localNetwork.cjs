const { isIP } = require('node:net');

// Android 17 gates local destinations, while loopback services remain reachable without a prompt.
const requiresLocalNetwork = hostname => {
    const host = String(hostname).toLowerCase().replace(/^\[|\]$/g, '').replace(/\.$/, '');
    if (host === 'localhost' || host.endsWith('.localhost') || host === '::1' || host === '0.0.0.0') return false;
    if (host.endsWith('.local') || host.endsWith('.lan')) return true;
    if (isIP(host) === 4) {
        const [a, b] = host.split('.').map(Number);
        return a === 10 || a === 172 && b >= 16 && b <= 31 || a === 192 && b === 168
            || a === 169 && b === 254 || a === 100 && b >= 64 && b <= 127 || a >= 224;
    }
    if (isIP(host) === 6) {
        if (host.startsWith('::ffff:')) {
            const tail = host.slice(7);
            if (isIP(tail) === 4) return requiresLocalNetwork(tail);
            const words = tail.split(':');
            if (words.length === 2) return requiresLocalNetwork([parseInt(words[0], 16) >> 8, parseInt(words[0], 16) & 255, parseInt(words[1], 16) >> 8, parseInt(words[1], 16) & 255].join('.'));
        }
        return /^f[cd]/.test(host) || /^fe[89ab]/.test(host) || host.startsWith('ff');
    }
    return false;
};
module.exports = { requiresLocalNetwork };

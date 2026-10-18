// A bounded event journal lets WebViews reconnect without losing the backend's current notifications.
module.exports = () => {
    let sequence = 0;
    const entries = [];
    const pendingNative = new Map();
    const nativeQueue = [];
    const waiting = [];
    const eventWaiters = new Set();
    const read = (after = 0, windowId = 1) => ({ cursor: sequence, entries: entries.filter(entry => entry.id > after && (!entry.windowId || entry.windowId === windowId)) });
    const notify = () => {
        for (const waiter of eventWaiters) {
            const result = read(waiter.after, waiter.windowId);
            if (!result.entries.length) continue;
            eventWaiters.delete(waiter); clearTimeout(waiter.timer); waiter.resolve(result);
        }
    };
    const takeNative = () => {
        while (nativeQueue.length) { const action = nativeQueue.shift(); if (pendingNative.has(action.id)) return action; }
        return null;
    };
    return {
        emit(channel, ...args) {
            entries.push({ id: ++sequence, channel, args });
            if (entries.length > 2000) entries.splice(0, entries.length - 2000);
            notify();
        },
        target(windowId, channel, ...args) {
            entries.push({ id: ++sequence, windowId, channel, args });
            if (entries.length > 2000) entries.splice(0, entries.length - 2000);
            notify();
        },
        read,
        waitEvents(after = 0, windowId = 1) {
            const result = read(after, windowId);
            if (result.entries.length) return Promise.resolve(result);
            return new Promise(resolve => {
                const waiter = { after, windowId, resolve, timer: null };
                waiter.timer = setTimeout(() => { eventWaiters.delete(waiter); resolve(read(after, windowId)); }, 25000);
                eventWaiters.add(waiter);
            });
        },
        native(method, ...args) {
            return new Promise((resolve, reject) => {
                const id = require('node:crypto').randomUUID();
                const timer = setTimeout(() => { pendingNative.delete(id); reject(new Error('Android did not answer ' + method)); }, method === 'ytmBrowserOpen' ? 15 * 60 * 1000 : 180000);
                pendingNative.set(id, { resolve, reject, timer });
                nativeQueue.push({ id, method, args });
                const waiter = waiting.shift();
                if (waiter) { clearTimeout(waiter.timer); waiter.resolve(takeNative()); }
            });
        },
        nextNative: takeNative,
        waitNative() {
            const action = takeNative();
            if (action) return Promise.resolve(action);
            return new Promise(resolve => {
                const waiter = { resolve, timer: null };
                waiter.timer = setTimeout(() => { const index = waiting.indexOf(waiter); if (index !== -1) waiting.splice(index, 1); resolve(null); }, 25000);
                waiting.push(waiter);
            });
        },
        completeNative(id, value, error) {
            const pending = pendingNative.get(id);
            if (!pending) return false;
            pendingNative.delete(id);
            clearTimeout(pending.timer);
            if (error) pending.reject(new Error(error));
            else pending.resolve(value);
            return true;
        },
    };
};

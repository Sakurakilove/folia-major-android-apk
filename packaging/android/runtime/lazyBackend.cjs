// Start a platform's local service only when a request actually needs its port.
module.exports = backend => {
    let pending = null;
    return async () => {
        if (backend.getPort() != null) return backend.getPort();
        if (!pending) pending = Promise.resolve().then(() => backend.start()).finally(() => { pending = null; });
        await pending;
        return backend.getPort();
    };
};

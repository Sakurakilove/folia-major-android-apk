const childProcess = require('node:child_process');

// End the backend's owned model, provider and encoder processes when the native host shuts it down.
module.exports = () => {
    const children = new Set();
    for (const method of ['spawn', 'fork', 'execFile']) {
        const original = childProcess[method];
        childProcess[method] = function (...args) {
            const child = original.apply(this, args);
            children.add(child); child.once('close', () => children.delete(child));
            return child;
        };
    }
    process.once('SIGTERM', () => process.exit(0));
    process.once('SIGINT', () => process.exit(0));
    process.once('exit', () => {
        for (const child of children) { try { child.kill('SIGKILL'); } catch { /* The child may have already exited. */ } }
    });
};

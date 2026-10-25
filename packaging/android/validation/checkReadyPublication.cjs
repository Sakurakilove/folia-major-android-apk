// Check the actual startup callback publishes readiness atomically without running the Android runtime.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync('packaging/android/runtime/main.cjs', 'utf8');
const published = new Map();
let wroteTemporary = false;
const startup = Promise.resolve();
vm.runInNewContext(source.slice(source.lastIndexOf('startup.then(')), {
    startup, path, dataDir: '/private/runtime-data',
    fs: {
        writeFileSync(file, content) {
            assert.equal(published.has('/private/runtime-data/ready.json'), false, 'readiness must not be visible while writing');
            assert.equal(file, '/private/runtime-data/ready.json.tmp');
            assert.equal(JSON.parse(content).port, 32123);
            published.set(file, content); wroteTemporary = true;
        },
        renameSync(from, to) {
            assert.ok(wroteTemporary);
            published.set(to, published.get(from)); published.delete(from);
        },
    },
    server: { address: () => ({ port: 32123 }), listen(port, host, callback) { assert.equal(host, '127.0.0.1'); callback(); } },
    console: { log() {}, error: console.error }, process,
});
setImmediate(() => {
    assert.deepEqual(JSON.parse(published.get('/private/runtime-data/ready.json')), { port: 32123 });
    assert.equal(published.size, 1);
    console.log('PASS: actual runtime readiness is published only after complete JSON write');
});

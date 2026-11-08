const Module = require('node:module');
const path = require('node:path');
const babel = require('@babel/core');
const commonjs = require('@babel/plugin-transform-modules-commonjs');
const crypto = require('node:crypto');
const { root, load, sourceText } = require('./original_source.cjs');

// Exercise the real original session store and focus hook. React is only a mount/cleanup adapter; all write, generation, eviction and flush rules come from the baseline.
module.exports = function sessionReference() {
    const source = 'src/library/core/shared/useLibraryBrowseSessionStore.ts',
        hook = 'src/library/suites/bravais/useBravaisSessionFocus.ts',
        original = load(source), store = original.useLibraryBrowseSessionStore,
        operations = [
            { op: 'query', key: 'missing', value: '' }, { op: 'focus', key: 'missing', value: null },
            { op: 'clear', key: 'missing' }, { op: 'clear', key: 'missing' },
            ...Array.from({ length: 34 }, (_, i) => ({ op: 'query', key: `collection:${i}`, value: `q${i}` })),
            { op: 'query', key: 'collection:2', value: 'q2' },
            { op: 'focus', key: 'collection:2', value: 'track:9' },
            { op: 'focus', key: 'collection:2', value: 'track:9' },
            { op: 'query', key: 'collection:34', value: 'q34' },
            { op: 'clear', key: 'collection:2' }, { op: 'clear', key: 'collection:2' },
            { op: 'focus', key: 'collection:2', value: 'track:10' },
        ], steps = [];
    let notifications = 0;
    const unsubscribe = store.subscribe(() => notifications++),
        snapshot = () => {
            const state = store.getState();
            return { order: state.order, sessions: Object.fromEntries(Object.keys(state.sessions).map(k => [k, state.sessions[k]])), notifications };
        };
    for (const input of operations) {
        const before = store.getState();
        if (input.op === 'query') before.setQuery(input.key, input.value);
        else if (input.op === 'focus') before.setFocusedEntry(input.key, input.value);
        else before.clearSession(input.key);
        steps.push({ input, same: before === store.getState(), generation: original.getLibrarySessionGeneration(input.key), ...snapshot() });
    }
    const file = path.join(root, hook), compiled = babel.transformSync(Module.stripTypeScriptTypes(sourceText(hook), { mode: 'transform' }),
        { plugins: [commonjs], configFile: false, babelrc: false }).code,
        instances = new Map(), writes = [], lifecycle = [],
        mount = (id, key) => {
            const cleanups = [], module = new Module(file);
            const react = { useState: initial => [initial(), () => {}], useRef: current => ({ current }), useCallback: run => run,
                useEffect: setup => { const cleanup = setup(); if (cleanup) cleanups.push(cleanup); } };
            const core = { ...original,
                useLibraryBrowseSessionStore: { getState: () => ({ ...store.getState(), setFocusedEntry: (k, value) => {
                    lifecycle.push(`write:${k}:${value}`); writes.push({ key: k, value }); store.getState().setFocusedEntry(k, value);
                } }) },
                registerLibrarySessionFlush: (k, run) => {
                    const unregister = original.registerLibrarySessionFlush(k, run);
                    return () => { lifecycle.push(`unregister:${id}`); unregister(); };
                } };
            module.filename = file; module.paths = Module._nodeModulePaths(path.dirname(file));
            const required = module.require.bind(module);
            module.require = request => request === 'react' ? react : request === '../../core/shared/useLibraryBrowseSessionStore' ? core : required(request);
            module._compile(compiled, file);
            const api = module.exports.useBravaisSessionFocus(key);
            instances.set(id, { api, cleanups });
        },
        focusOps = [
            { op: 'seed', key: 'focus', value: 'original' }, { op: 'mount', id: 'a', key: 'focus' },
            { op: 'flush', key: 'focus' }, { op: 'note', id: 'a', value: 'moved' }, { op: 'flush', key: 'focus' },
            { op: 'flush', key: 'focus' }, { op: 'note', id: 'a', value: null }, { op: 'flush', key: 'focus' },
            { op: 'persist', id: 'a' }, { op: 'note', id: 'a', value: '' }, { op: 'flush', key: 'focus' },
            { op: 'persist', id: 'a' }, { op: 'persist', id: 'a', value: 'nested' },
            { op: 'clear', key: 'focus' }, { op: 'flush', key: 'focus' },
            { op: 'persist', id: 'a', value: 'explicit-after-clear' }, { op: 'note', id: 'a', value: 'stale' },
            { op: 'mount', id: 'b', key: 'focus' }, { op: 'note', id: 'b', value: 'new-owner' },
            { op: 'unmount', id: 'a' }, { op: 'flush', key: 'focus' },
            { op: 'persist', id: 'b', value: null }, { op: 'flush', key: 'focus' },
            { op: 'note', id: 'b', value: 'final' }, { op: 'unmount', id: 'b' }, { op: 'flush', key: 'focus' },
            { op: 'mount', id: 'c', key: 'clear-before-unmount' }, { op: 'note', id: 'c', value: 'gone' },
            { op: 'clear', key: 'clear-before-unmount' }, { op: 'unmount', id: 'c' },
            { op: 'mount', id: 'd', key: 'untouched' }, { op: 'unmount', id: 'd' },
        ], focus = [];
    for (const input of focusOps) {
        const instance = instances.get(input.id);
        if (input.op === 'seed') store.getState().setFocusedEntry(input.key, input.value);
        else if (input.op === 'mount') mount(input.id, input.key);
        else if (input.op === 'note') instance.api.noteFocus(input.value);
        else if (input.op === 'persist') Object.hasOwn(input, 'value') ? instance.api.persistFocus(input.value) : instance.api.persistFocus();
        else if (input.op === 'unmount') instance.cleanups.forEach(run => run());
        else if (input.op === 'clear') store.getState().clearSession(input.key);
        else original.flushLibrarySession(input.key);
        focus.push({ input, initials: Object.fromEntries([...instances].map(([id, item]) => [id, item.api.initialKey])), writes: [...writes], lifecycle: [...lifecycle], ...snapshot() });
    }
    unsubscribe();
    return { sourceHashes: Object.fromEntries([source, hook].map(s => [s, crypto.createHash('sha256').update(sourceText(s)).digest('hex')])), steps, focus };
};

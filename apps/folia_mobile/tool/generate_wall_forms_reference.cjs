const fs = require('node:fs');
const Module = require('node:module');
const path = require('node:path');
const crypto = require('node:crypto');
const babel = require('@babel/core');
const commonjs = require('@babel/plugin-transform-modules-commonjs');
const { root, baseline, load, sourceText } = require('./original_source.cjs');

// Actual source reducer, notice formatter and async form executor; no browser mount or duplicate transition rules.
async function main() {
    const paths = ['src/library/suites/bravais/bravaisFormModel.ts', 'src/library/suites/bravais/useBravaisCollectionForms.ts',
        'src/library/suites/bravais/bravaisCollectionStatus.ts'],
        model = load(paths[0]), status = load(paths[2]),
        labels = { limitReached: 'limit', dislikeFailed: 'dislike', failed: 'failed', stale: 'stale', unsupported: 'unsupported' },
        results = [{ ok: true }, ...['busy', 'stale', 'unsupported', 'limit-reached', 'failed'].map(reason => ({ ok: false, reason })),
            { ok: false, reason: 'failed', message: '' }, { ok: false, reason: 'failed', message: 'upstream' }],
        notices = results.flatMap(result => [false, true].map(isDailyRemoval => ({ result, isDailyRemoval, described: status.describeMutationResult(result, labels, { isDailyRemoval }) }))),
        events = [{ type: 'start-create' }, { type: 'open-rename', initial: 'Name' }, { type: 'start-create' },
            { type: 'result', result: { ok: false, reason: 'failed', message: 'raw' } },
            { type: 'result', result: { ok: false, reason: 'busy' }, errorText: 'ignored' },
            { type: 'result', result: { ok: false, reason: 'failed', message: 'raw' }, errorText: '' },
            { type: 'result', result: { ok: false, reason: 'failed', message: 'raw' }, errorText: 'translated' },
            { type: 'result', result: { ok: true } }, { type: 'open-delete' }, { type: 'result', result: { ok: false, reason: 'unsupported' } },
            { type: 'cancel' }, { type: 'open-pick', scope: { kind: 'entry', entryKey: 'track:1' } }, { type: 'start-create' },
            { type: 'result', result: { ok: false, reason: 'stale' }, errorText: 'gone' }, { type: 'start-create' },
            { type: 'cancel' }, { type: 'cancel' }, { type: 'result', result: { ok: false, reason: 'failed' } },
            { type: 'open-pick', scope: { kind: 'collection' } }, { type: 'result', result: { ok: false, reason: 'busy' } }, { type: 'cancel' }],
        reducer = [];
    let state = null;
    for (const event of events) {
        const before = state; state = model.reduceBravaisForm(state, event);
        reducer.push({ event, state, same: before === state, open: model.hasOpenForm(state) });
    }
    const calls = [], cells = [], pending = [], deferred = [];
    let cursor = 0, version = 0, available = true, runNull = false, api;
    const react = {
        useReducer(reduce, initial) { const i = cursor++; cells[i] ??= { value: initial }; return [cells[i].value, event => { cells[i].value = reduce(cells[i].value, event); }]; },
        useRef(current) { const i = cursor++; return cells[i] ??= { current }; }, useCallback: run => run, useMemo: run => run(),
    }, controller = v => ({
        rename: text => request({ op: 'rename', version: v, text }),
        deleteCollection: () => request({ op: 'delete', version: v }),
        createPlaylist: (text, tracks) => request({ op: 'create', version: v, text, tracks }),
        addToPlaylist: (playlistId, tracks) => request({ op: 'add', version: v, playlistId, tracks }),
    }), request = payload => { calls.push(payload); return new Promise(resolve => deferred.push(resolve)); },
        file = path.join(root, paths[1]), module = new Module(file);
    module.filename = file; module.paths = Module._nodeModulePaths(path.dirname(file));
    const required = module.require.bind(module); module.require = r => r === 'react' ? react : required(r);
    module._compile(babel.transformSync(Module.stripTypeScriptTypes(sourceText(paths[1]), { mode: 'transform' }), { plugins: [commonjs], configFile: false, babelrc: false }).code, file);
    const render = () => {
        cursor = 0; const v = version, nullResult = runNull;
        api = module.exports.useBravaisCollectionForms({ mutations: available ? controller(v) : null, displayTitle: `Title ${v}`,
            tracksFor: scope => { calls.push({ op: 'tracks', version: v, scope }); return [`v${v}:${scope.kind === 'entry' ? scope.entryKey : 'all'}`]; },
            run: async action => { calls.push({ op: 'run', version: v }); return nullResult ? null : await action(); },
            describe: result => { calls.push({ op: 'describe', version: v, result }); return !result.ok && result.reason !== 'busy' ? `v${v}:${result.reason}` : undefined; },
            onBack: () => calls.push({ op: 'back', version: v }) });
    }, operations = [
        { op: 'submit', text: 'no form' }, { op: 'rename' }, { op: 'begin-submit', text: 'new title' },
        { op: 'update', version: 1 }, { op: 'complete', result: { ok: false, reason: 'failed', message: 'denied' } },
        { op: 'begin-submit', text: 'retry' }, { op: 'complete', result: { ok: false, reason: 'busy' } },
        { op: 'begin-submit', text: 'done' }, { op: 'complete', result: { ok: true } },
        { op: 'delete' }, { op: 'begin-submit', text: '' }, { op: 'update', version: 2 }, { op: 'complete', result: { ok: true } },
        { op: 'open-pick', scope: { kind: 'entry', entryKey: 'track:1' } }, { op: 'begin-pick', playlistId: 12 }, { op: 'cancel' },
        { op: 'complete', result: { ok: false, reason: 'failed' } },
        { op: 'open-pick', scope: { kind: 'collection' } }, { op: 'submit', text: 'not creating' }, { op: 'start-create' },
        { op: 'begin-submit', text: 'New playlist' }, { op: 'update', version: 3, available: false },
        { op: 'complete', result: { ok: false, reason: 'unsupported' } }, { op: 'cancel' }, { op: 'pick', playlistId: 'without controller' },
        { op: 'rename' }, { op: 'submit', text: 'without controller' }, { op: 'update', version: 4, runNull: true },
        { op: 'submit', text: 'null result' }, { op: 'cancel' },
        { op: 'update', version: 5 }, { op: 'open-pick', scope: { kind: 'collection' } }, { op: 'start-create' },
        { op: 'begin-pick', playlistId: 'while creating' }, { op: 'rename' }, { op: 'complete', result: { ok: false, reason: 'stale' } },
    ], execution = [];
    render();
    for (const input of operations) {
        if (input.op === 'rename') api.openRename();
        else if (input.op === 'delete') api.openDelete();
        else if (input.op === 'open-pick') api.openPick(input.scope);
        else if (input.op === 'start-create') api.startCreate();
        else if (input.op === 'cancel') api.cancel();
        else if (input.op === 'begin-submit') pending.push(api.submit(input.text));
        else if (input.op === 'begin-pick') pending.push(api.pick(input.playlistId));
        else if (input.op === 'submit') await api.submit(input.text);
        else if (input.op === 'pick') await api.pick(input.playlistId);
        else if (input.op === 'complete') { deferred.shift()(input.result); await pending.shift(); }
        else { version = input.version; available = input.available !== false; runNull = !!input.runNull; }
        render(); execution.push({ input, state: api.state, calls: [...calls] });
    }
    fs.writeFileSync(path.join(__dirname, '../test/fixtures/wall_forms_reference.json'), JSON.stringify({ baseline,
        scope: 'Original reducer, mutation labels and async executor only. Complete forms, provider mutations and device/visual acceptance remain pending.',
        sourceHashes: Object.fromEntries(paths.map(p => [p, crypto.createHash('sha256').update(sourceText(p)).digest('hex')])), labels, notices, reducer, execution }, null, 2) + '\n');
    console.log(`Exported ${reducer.length} form transitions, ${notices.length} notices and ${execution.length} async lifecycle steps.`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });

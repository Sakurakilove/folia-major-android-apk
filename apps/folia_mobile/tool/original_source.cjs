const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const babel = require('@babel/core');
const commonjs = require('@babel/plugin-transform-modules-commonjs');
const { execFileSync } = require('node:child_process');

// Build-time access to original TS value exports; no JavaScript runtime is embedded in the Android app.
const root = path.resolve(__dirname, '../../..');
const baseline = '45d7d8a27afc7efb7a33308824def68329a86651';
const sourceText = relative => execFileSync('git', ['show', `${baseline}:${relative}`], { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
const compile = (source, typed) => babel.transformSync(typed
    ? Module.stripTypeScriptTypes(source, { mode: 'transform' }) : source,
    { plugins: [commonjs], configFile: false, babelrc: false }).code;
require.extensions['.ts'] = (module, file) => module._compile(compile(file.startsWith(root + path.sep)
    ? sourceText(path.relative(root, file)) : fs.readFileSync(file, 'utf8'), true), file);
const load = relative => require(path.join(root, relative));
const loadJavaScript = relative => {
    const file = path.join(root, relative), module = new Module(file);
    module.filename = file;
    module.paths = Module._nodeModulePaths(path.dirname(file));
    const originalRequire = module.require.bind(module);
    module.require = request => request.startsWith('.') && request.endsWith('.mjs')
        ? loadJavaScript(path.relative(root, path.resolve(path.dirname(file), request))) : originalRequire(request);
    module._compile(compile(sourceText(relative), false), file);
    return module.exports;
};
module.exports = { root, baseline, load, loadJavaScript, sourceText };

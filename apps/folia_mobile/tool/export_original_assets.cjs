const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const { root, baseline, load, loadJavaScript, sourceText } = require('./original_source.cjs');

// Export original resources verbatim; generated metadata keeps their exact source digests and license.
const out = path.join(__dirname, '../assets/original');
const inputs = {};
const digest = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const track = relative => {
    const buffer = fs.readFileSync(path.join(root, relative));
    const actual = crypto.createHash('sha256').update(buffer).digest('hex');
    if (!relative.endsWith('.png')) {
        const expected = crypto.createHash('sha256').update(sourceText(relative)).digest('hex');
        if (actual !== expected) throw new Error(`Original resource changed from baseline: ${relative}`);
    }
    inputs[relative] = actual;
};
const write = (relative, value) => {
    const file = path.join(out, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, JSON.stringify(value) + '\n');
};
const locales = {};
for (const language of ['en', 'zh-CN', 'in']) {
    const file = `src/i18n/locales/${language}.ts`;
    locales[language] = load(file).default;
    track(file);
    write(`locales/${language}.json`, locales[language]);
}
const { toTaiwanTraditional } = loadJavaScript('dev/i18n/localeTextRewrite.mjs');
track('dev/i18n/localeTextRewrite.mjs'); track('dev/i18n/traditionalTerms.mjs');
const traditional = value => typeof value === 'string' ? toTaiwanTraditional(value)
    : Array.isArray(value) ? value.map(traditional)
    : Object.fromEntries(Object.entries(value).map(([key, child]) => [key, traditional(child)]));
write('locales/zh-TW.json', traditional(locales['zh-CN']));
track('src/services/baseThemes.ts'); track('src/types.ts'); track('src/types/visualizerModes.ts');
const types = load('src/types.ts');
write('defaults.json', { ...load('src/services/baseThemes.ts'), ...Object.fromEntries(Object.entries(types).filter(([name]) => name.startsWith('DEFAULT_'))) });
write('modes.json', load('src/types/visualizerModes.ts'));
// Dynamic import keys are the original resolver's source of truth, including aliases.
const lucideRoot = path.dirname(require.resolve('lucide-react/package.json'));
const dynamic = fs.readFileSync(path.join(lucideRoot, 'dist/esm/dynamicIconImports.mjs'), 'utf8');
const keys = [...dynamic.matchAll(/"([^"]+)":\s*\(\)\s*=>\s*import\(['"]\.\/icons\/([^'"]+)['"]\)/g)].map(m => [m[1], m[2]]);
if (!keys.length) throw new Error('Lucide import shape changed; refusing an empty icon catalog');
const iconData = (file, seen = new Set()) => {
    if (seen.has(file)) throw new Error(`Cyclic icon alias: ${file}`);
    seen.add(file);
    const source = fs.readFileSync(file, 'utf8');
    const data = source.match(/const __iconData = ([\s\S]+?);\r?\n/);
    if (data) return vm.runInNewContext(`(${data[1]})`, {}, { timeout: 1000 });
    const reexport = source.match(/export\s*\{\s*default\s*\}\s*from\s*['"]([^'"]+)['"]/);
    if (reexport) return iconData(path.resolve(path.dirname(file), reexport[1]), seen);
    throw new Error(`Unsupported Lucide module: ${file}`);
};
const tags = new Set(), attributes = new Set();
for (const [key, file] of keys) {
    const data = iconData(path.join(lucideRoot, 'dist/esm/icons', file));
    for (const [tag, attrs] of data.node) { tags.add(tag); for (const name of Object.keys(attrs)) attributes.add(name); }
    write(`icons/${key}.json`, data);
}
const names = {};
const pascal = key => key.replace(/(?:^|-)(\w)/g, (_, char) => char.toUpperCase());
for (const form of [name => name, name => `${name}Icon`, name => `Lucide${name}`]) {
    for (const [key] of keys) { const name = form(pascal(key)); names[name] ??= key; }
}
const packageInfo = JSON.parse(fs.readFileSync(path.join(lucideRoot, 'package.json'), 'utf8'));
write('icons/index.json', { version: packageInfo.version, names });
fs.copyFileSync(path.join(lucideRoot, 'LICENSE'), path.join(out, 'Lucide-LICENSE.txt'));
fs.copyFileSync(path.join(root, 'public/icon.svg'), path.join(out, 'icon.svg'));
track('public/icon.svg');
const androidResources = path.join(root, 'android/app/src/main/res');
const nativeResources = path.join(__dirname, '../android/app/src/main/res');
for (const folder of fs.readdirSync(androidResources)) {
    if (!folder.startsWith('mipmap-')) continue;
    for (const name of fs.readdirSync(path.join(androidResources, folder))) {
        if (!name.startsWith('ic_launcher')) continue;
        const relative = `android/app/src/main/res/${folder}/${name}`;
        fs.mkdirSync(path.join(nativeResources, folder), { recursive: true });
        fs.copyFileSync(path.join(root, relative), path.join(nativeResources, folder, name)); track(relative);
    }
}
for (const relative of ['drawable-nodpi/folia_icon.png', 'values/folia_colors.xml']) {
    fs.mkdirSync(path.dirname(path.join(nativeResources, relative)), { recursive: true });
    fs.copyFileSync(path.join(androidResources, relative), path.join(nativeResources, relative));
    track(`android/app/src/main/res/${relative}`);
}
write('provenance.json', { baseline,
    generator: 'tool/export_original_assets.cjs', inputs, lucide: { version: packageInfo.version, icons: keys.length,
    importMapSha256: digest(path.join(lucideRoot, 'dist/esm/dynamicIconImports.mjs')), licenseSha256: digest(path.join(lucideRoot, 'LICENSE')) },
    note: 'Resource equality is not rendered frontend/animation parity.' });
console.log({ locales: 4, lucideIcons: keys.length, tags: [...tags], attributes: [...attributes] });

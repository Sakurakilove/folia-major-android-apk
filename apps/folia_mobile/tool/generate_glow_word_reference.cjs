const fs = require('node:fs');
const { pathToFileURL } = require('node:url');
const path = require('node:path');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const { baseline, sourceText, load } = require('./original_source.cjs');

// Execute the baseline timing functions and actual Classic useMemo body; synthetic widths are explicitly not font proof.
const timing = load('src/components/visualizer/glowWordTiming.ts');
const source = sourceText('src/components/visualizer/classic/Visualizer.tsx');
const body = source.slice(source.indexOf('        if (!activeLine) return { wordConfigs'),
    source.indexOf('    }, [activeLine, displayWords,'));
const layouts = [];
for (const seed of [-.2, 0, 2.25, 17.8]) for (const intensity of ['calm', 'normal', 'chaotic'])
    for (const legacy of [false, true]) {
        const words = ['It', '’', 's', '世界', 'unbelievable'].map((text, i) => ({ text, startTime: seed + i / 3, endTime: seed + (i + 1) / 3 }));
        const tuning = { enableWordRotation: seed !== 2.25, breathingFloatMultiplier: 1, useLegacyLayout: legacy, wordSpacing: .7 };
        const line = { startTime: seed, endTime: seed + 2, fullText: seed === 17.8 ? '......' : 'It’s 世界 unbelievable', words };
        const sandbox = { activeLine: line, theme: { animationIntensity: intensity }, resolvedClassicTuning: tuning,
            displayWords: words, viewportWidth: seed === 2.25 ? 1600 : 360, lyricsFontScale: 1.2,
            resolveThemeFontStack: () => '', resolveThemeFontWeight: () => 700,
            measureWordWidth: (text, px) => text.length * px * .57 };
        vm.runInNewContext(stripTypeScriptTypes(`globalThis.result=(()=>{${body}})();`, { mode: 'transform' }), sandbox);
        layouts.push({ line, tuning, intensity, viewportWidth: sandbox.viewportWidth, lyricsFontScale: 1.2, expected: sandbox.result });
    }
const variants = load('src/components/visualizer/glowWordVariants.ts');
const variantCases = [];
for (const intensity of ['calm', 'normal', 'chaotic']) for (const rotation of [true, false])
    for (const reveal of ['normal', 'fast', 'instant']) {
        const config = { x: 12.25, y: -5.7, rotate: rotation ? 13 : 0, scale: 1.19, passedRotate: rotation ? 3.3 : 0 };
        const custom = { config, baseColor: '#123456', activeColor: '#fedcba', duration: .27, wordRevealMode: reveal };
        const layout = variants.buildGlowWordLayoutVariants(intensity, rotation);
        variantCases.push({ intensity, rotation, reveal, config, custom, states: Object.fromEntries(['waiting', 'active', 'passed'].map(state =>
            [state, { layout: layout[state](custom), body: variants.glowWordBodyVariants[state](custom) }])) });
    }
const profiles = [];
for (const duration of [.03, .12, 2]) {
    const line = { startTime: 4, endTime: 4 + duration, fullText: 'word', words: [
        { text: 'word', startTime: 4, endTime: 4 + duration * .5 }] };
    const profile = timing.resolveGlowWordRenderProfile(line);
    profiles.push({ line, expected: profile, motion: timing.getGlowWordLineContainerMotion(profile),
        words: line.words.map(word => ({ word, end: timing.getGlowWordActiveEndTime(word, profile), duration: timing.getGlowWordDisplayDuration(word, profile) })) });
}
async function finish() {
const installedVersion = JSON.parse(fs.readFileSync(path.resolve(path.dirname(require.resolve('motion-dom')), '../../package.json'), 'utf8')).version;
const originalVersion = JSON.parse(sourceText('package-lock.json')).packages['node_modules/motion-dom'].version;
if (installedVersion !== originalVersion) throw new Error('Motion dependency differs from the original lockfile');
const { spring } = await import(pathToFileURL(require.resolve('motion-dom').replace(/dist\/cjs\/index\.js$/, 'dist/es/animation/generators/spring.mjs')).href);
const physics = [];
for (const config of [{stiffness:142,damping:28,mass:.82}, {stiffness:150,damping:30,mass:.78}, {stiffness:200,damping:20,mass:1},
    {stiffness:100,damping:20,mass:1}, {stiffness:500,damping:25,mass:1}]) for (const [from,to,velocity] of [[0,100,0], [1,.98,0], [10,-13,67]]) {
    const generator = spring({ ...config, keyframes: [from,to], velocity });
    physics.push({config,from,to,velocity,samples:[0,1,16,33,66,100,250,500,1000,3000].map(ms=>({ms,...generator.next(ms),velocity:generator.velocity(ms)}))});
}
fs.writeFileSync(path.join(__dirname, '../test/fixtures/glow_word_reference.json'), JSON.stringify({ baseline,
    scope: 'Shared timing and Classic layout body with synthetic code-unit widths; no fonts, pixels, gestures or full animation acceptance.',
    physics, layouts, variantCases, profiles, nullMotion: timing.getGlowWordLineContainerMotion(null) }, null, 2) + '\n');
console.log(`${layouts.length} original Classic layouts and ${profiles.length} shared timing profiles generated.`);

}
finish().catch(error=>{console.error(error);process.exitCode=1;});

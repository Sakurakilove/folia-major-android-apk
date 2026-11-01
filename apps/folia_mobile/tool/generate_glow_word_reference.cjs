const fs = require('node:fs');
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
fs.writeFileSync(path.join(__dirname, '../test/fixtures/glow_word_reference.json'), JSON.stringify({ baseline,
    scope: 'Shared timing and Classic layout body with synthetic code-unit widths; no fonts, pixels, gestures or full animation acceptance.',
    layouts, variantCases, profiles, nullMotion: timing.getGlowWordLineContainerMotion(null) }, null, 2) + '\n');
console.log(`${layouts.length} original Classic layouts and ${profiles.length} shared timing profiles generated.`);

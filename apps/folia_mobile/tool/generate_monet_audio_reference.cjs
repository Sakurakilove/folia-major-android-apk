const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const { baseline, sourceText, load } = require('./original_source.cjs');

// Execute actual original AudioOverlay helper/draw bodies; no parallel reimplementation as an oracle.
const source = sourceText('src/components/visualizer/monet/AudioOverlay.tsx');
const helpers = source.slice(source.indexOf('const BAR_COUNT'), source.indexOf('const AudioOverlay:'));
const draw = source.slice(source.indexOf('        const draw = () => {'), source.indexOf('        const handleResize ='));
const colors = load('src/components/visualizer/colorMix.ts');
const cases = [];
for (const length of [0, 64, 1024]) for (const mode of ['bar', 'line']) for (const staticMode of [false, true]) {
    const raw = Uint8Array.from({ length }, (_, i) => (i * 37 + 51) % 256);
    const bands = [32, 64, 128, 192, 224], width = length === 64 ? 310 : 450, height = 40, nowMs = 12345;
    const bars = [], paths = [];
    let current;
    const context = {
        clearRect() {}, fillRect: (...rect) => bars.push(rect),
        beginPath() { current = []; paths.push(current); },
        moveTo: (...p) => current.push(['move', ...p]),
        lineTo: (...p) => current.push(['line', ...p]),
        quadraticCurveTo: (...p) => current.push(['quad', ...p]),
        closePath() {}, fill() {}, stroke() {}, createLinearGradient: () => ({ addColorStop() {} }),
    };
    const sandbox = { Math, Uint8Array, colorWithAlpha: colors.colorWithAlpha, context, canvasWidth: width, canvasHeight: height,
        mode, theme: { primaryColor: '#123456' }, performance: { now: () => nowMs }, audioPower: { get: () => 93 },
        audioBands: Object.fromEntries(['bass', 'lowMid', 'mid', 'vocal', 'treble'].map((key, i) => [key, { get: () => bands[i] }]).concat([['spectrum', { get: () => raw }]])),
        resolveGradients: () => ({ gradient: 'ink', fillGradient: 'area' }) };
    const setup = `let spectrumLength=-1; let spectrumSamplers=[]; const linePoints=Array.from({length:72},()=>({x:0,y:0}));`;
    const script = helpers + setup + draw + (staticMode ? ';drawStaticBars(context,canvasWidth,canvasHeight,theme,mode);' : ';draw();') + ';globalThis.points=linePoints;';
    vm.runInNewContext(stripTypeScriptTypes(script, { mode: 'transform' }), sandbox);
    let points = [];
    if (mode === 'line') {
        if (!staticMode) points = sandbox.points.map(p => [p.x, p.y]);
        else {
            const curve = paths.at(-1);
            points = curve.filter(p => p[0] === 'quad').map(p => p.slice(1, 3));
            points.push(curve.at(-1).slice(1, 3));
        }
    }
    cases.push({ length, mode, staticMode, raw: [...raw], bands, power: 93, width, height, nowMs, bars, points });
}
fs.writeFileSync(path.join(__dirname, '../test/fixtures/monet_audio_reference.json'), JSON.stringify({ baseline,
    scope: 'Original AudioOverlay numeric draw coordinates only; no raster, font, post-effects or device-power equivalence claimed.', cases }, null, 2) + '\n');
console.log(`${cases.length} original audio-overlay draw cases generated.`);

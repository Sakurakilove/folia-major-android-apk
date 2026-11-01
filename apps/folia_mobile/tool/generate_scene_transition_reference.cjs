const fs = require('node:fs');
const path = require('node:path');
const { baseline, load } = require('./original_source.cjs');

// Execute the baseline layer reducer for rapid reversals, first-frame reports, stale reports and animation changes.
const { nextShownLayers, startedLayers } = load('src/components/visualizer/styleTransition/layerTransition.ts');
const transition = load('src/components/visualizer/styleTransition/softFocus.ts').default;
const cases = [];
const seeds = [
    [{ key: 0, value: 'classic', leaving: false, comesIn: false, waits: false }],
    [{ key: 0, value: 'classic', leaving: true, comesIn: false, waits: true },
        { key: 1, value: 'monet', leaving: false, comesIn: true, waits: true }],
    [{ key: 0, value: 'classic', leaving: true, comesIn: false, waits: false },
        { key: 1, value: 'monet', leaving: false, comesIn: true, waits: false }],
];
for (const layers of seeds) for (const value of ['classic', 'monet', 'fume', 'still'])
    for (const animate of [false, true]) for (const waits of [false, true]) {
        const expected = nextShownLayers(layers, value, animate, waits);
        cases.push({ layers, value, animate, waits, expected,
            starts: [0, 1, 999].map(key => ({ key, expected: startedLayers(expected, key) })) });
    }
fs.writeFileSync(path.join(__dirname, '../test/fixtures/scene_transition_reference.json'), JSON.stringify({ baseline,
    scope: 'Baseline layer states and transition constants only; not rasterization, full host integration or visual acceptance.', transition, cases }, null, 2) + '\n');
console.log(`${cases.length} original layer transition cases generated.`);

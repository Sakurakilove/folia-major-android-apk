const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { baseline, load, sourceText } = require('./original_source.cjs');

// Small source-derived contract for the shared glyph ramp and Motion color mixer, not screenshot or whole-scene acceptance.
async function main() {
    const quantize = load('src/utils/glowBlurQuantize.ts');
    const { wordGlowVariants } = load('src/components/visualizer/wordGlow.ts');
    const ramps = [];
    for (const quantized of [false, true]) for (const reveal of ['normal', 'fast', 'instant'])
        for (const duration of [0, .04, .4]) for (const timing of [{}, {index:1,total:3},
            {index:1,total:3,charStartTime:4.12,charEndTime:4.21,wordStartTime:4}]) {
            quantize.setGlowBlurQuantized(quantized);
            const custom = {activeColor:'#abcdef',duration,wordRevealMode:reveal,...timing};
            const active = wordGlowVariants.active(custom);
            const radii = quantized ? [...active.filter[1].matchAll(/0 0 ([\d.]+)px/g)].map(m=>Number(m[1]))
                : [...active.textShadow[1].matchAll(/0 0 ([\d.]+)px/g)].map(m=>Number(m[1]));
            const peaks = quantized ? active.opacity : active.textShadow.map(v=>v==='none'?0:1);
            ramps.push({quantized,custom,radii,peaks,transition:active.transition,passed:wordGlowVariants.passed(custom).transition});
        }
    const installed = JSON.parse(fs.readFileSync(path.resolve(path.dirname(require.resolve('motion-dom')), '../../package.json'), 'utf8')).version;
    if (installed !== JSON.parse(sourceText('package-lock.json')).packages['node_modules/motion-dom'].version) throw Error('Motion version changed');
    const es = path.resolve(path.dirname(require.resolve('motion-dom')), '../es');
    const {mixColor} = await import(pathToFileURL(path.join(es,'utils/mix/color.mjs')));
    const {rgba} = await import(pathToFileURL(path.join(es,'value/types/color/rgba.mjs')));
    const colors = [['#000','#fff'],['#1234','#fedcba98'],['rgba(20, 60, 100, .2)','rgba(210, 150, 40, .8)'],
        ['hsl(220, 50%, 40%)','hsla(40, 70%, 80%, .4)'],['rgb(20%, 60%, 100%)','#acf']].map(([from,to])=>({from,to,
            samples:[-.2,0,.25,.5,1,1.2].map(progress=>({progress,value:rgba.parse(mixColor(from,to)(progress))}))}));
    fs.writeFileSync(path.join(__dirname,'../test/fixtures/glow_ramp_reference.json'),JSON.stringify({baseline,
        scope:'Typed ramp parameters and Motion JS explicit colors only; no glyph pixels or settings-toggle acceptance.',ramps,colors},null,2)+'\n');
    console.log(`${ramps.length} original ramps and ${colors.length * 6} explicit-color samples generated.`);
}
main().catch(error=>{console.error(error);process.exitCode=1;});

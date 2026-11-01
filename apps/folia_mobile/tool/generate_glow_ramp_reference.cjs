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
    const {springValue}=await import(pathToFileURL(path.join(es,'value/spring-value.mjs')));
    const {time}=await import(pathToFileURL(path.join(es,'frameloop/sync-time.mjs')));
    const followers=[];
    for (const options of [{stiffness:280,damping:28},{stiffness:100,damping:10},{stiffness:142,damping:28,mass:.82}]) {
        let now=0,tick;
        const value=springValue(1,{...options,driver:update=>{tick=update;return {now:()=>now,start(){},stop(){}};}});
        const steps=[];
        for (const step of [{ms:0,set:0,tick:true},{ms:10.2,tick:true},{ms:20.7,tick:true},
            {ms:22,set:.4},{ms:22,set:.8},{ms:33.333,tick:true},{ms:49.9,tick:true},
            {ms:66.6,set:1},{ms:83.3,tick:true},{ms:100,tick:true},{ms:125,set:0},
            {ms:133.333,tick:true},{ms:180,tick:true},{ms:250,tick:true},{ms:800,tick:true},
            {ms:2000,tick:true},{ms:2100,set:1},{ms:2116.5,tick:true},{ms:2150,tick:true},{ms:2500,tick:true},{ms:4000,tick:true}]) {
            now=step.ms;time.set(now);
            if ('set' in step) value.set(step.set);
            if (step.tick) tick(now);
            steps.push({...step,value:value.get(),running:value.animation?.state==='running'});
            await Promise.resolve();
        }
        value.destroy();followers.push({options,steps});
    }
    fs.writeFileSync(path.join(__dirname,'../test/fixtures/glow_ramp_reference.json'),JSON.stringify({baseline,
        scope:'Typed ramps, explicit colors and source useSpring follower ticks only; no glyph pixels or settings-toggle acceptance.',ramps,colors,followers},null,2)+'\n');
    console.log(`${ramps.length} original ramps and ${colors.length * 6} explicit-color samples generated.`);
}
main().catch(error=>{console.error(error);process.exitCode=1;});

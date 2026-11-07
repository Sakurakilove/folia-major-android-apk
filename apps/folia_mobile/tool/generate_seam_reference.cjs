const fs = require('node:fs');
const path = require('node:path');
const { baseline, load } = require('./original_source.cjs');

// Small source-only seam contract; all UI/focus/pixel checks remain a separate final gate.
const target = load('src/library/suites/bravais/bravaisSeamTarget.ts');
const level = load('src/library/suites/bravais/bravaisSeamLevel.ts');
const targets=[];
for(const surface of ['home','collection','artist']) for(const value of ['hidden','spine','full']) {
    for(const flags of [{},{filterOpen:true},{panelOpen:true,poster:true},{formOpen:true,panelOpen:true},{searchOpen:true,poster:true},{poster:true}]) {
        const input={surface,level:value,viewportWidth:390,...flags};
        targets.push({input,target:target.resolveSeamTarget(input),effective:target.resolveEffectiveSeamLevel(input)});
    }
}
let state={level:'full',restoreLevel:'full'};
const operations=[{kind:'apply',value:'hidden'},{kind:'resize',from:1280,to:390},{kind:'restore'},
    {kind:'apply',value:'full'},{kind:'resize',from:390,to:899},{kind:'resize',from:899,to:900},
    {kind:'apply',value:'spine'},{kind:'apply',value:'hidden'},{kind:'restore'}],states=[];
for(const op of operations) {
    state=op.kind==='apply'?level.applySeamLevel(state,op.value):op.kind==='restore'?level.restoreSeamLevel(state):level.resolveSeamLevelOnResize(state,op.from,op.to);
    states.push(state);
}
const motions=require('./wall_seam_oracle.cjs')();
fs.writeFileSync(path.join(__dirname,'../test/fixtures/seam_reference.json'),JSON.stringify({baseline,targets,operations,states,motions},null,2)+'\n');
console.log('Exported original seam target/level cases and nineteen actual hook/WAAPI identity steps.');

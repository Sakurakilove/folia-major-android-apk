const fs = require('node:fs');
const path = require('node:path');
const { baseline, load } = require('./original_source.cjs');

// Original source projection check: transparency/ranks/headings/removal. No running app, screenshots or timers.
const model = load('src/library/suites/bravais/bravaisDisplay.ts'), finite = load('src/library/suites/bravais/bravaisFiniteWall.ts');
const shapes = load('src/library/suites/bravais/bravaisWallShape.ts'), removal = load('src/library/suites/bravais/bravaisRemoval.ts');
const updates = load('src/library/suites/bravais/bravaisDisplayUpdate.ts');
const bounds = {left:-1000,right:2000,top:-900,bottom:1800}, center = {x:-400,y:120}, view = {width:390,height:844,scale:.52};
const items = Array.from({length:8},(_,i)=>({key:`key-${i}`,kind:'track',title:`Track ${i}`,subtitle:'',badge:String(i)}));
const sections = [{key:'first',heading:'First',entries:items.slice(0,3).map((_,index)=>({index,kind:'song'}))},
    {key:'second',heading:'Second',entries:items.slice(3).map((_,i)=>({index:i+3,kind:'song'}))}];
const cases = [];
for (const explore of [false,true]) for (const mode of ['infinite','finite']) for (const look of ['solid','partial','clear']) {
    const layer = {key:'layer',sessionKey:'session',mode,items,wall:{periodCount:11,planCount:23,filterKey:'f',isLoading:false},
        shape:explore?{kind:'explore',sections,headings:sections.map((s,i)=>({key:`heading-${i}`,kind:'feed',title:s.heading,subtitle:'',badge:String(i)}))}:undefined};
    const display = model.createBravaisDisplay(layer,'-1,0,5',undefined,{look,windowsPerBlock:3});
    if (mode==='finite') display.finite = finite.planBravaisFinite({count:23,anchorX:-4,center,view,reservedPerBlock:display.reservedPerBlock});
    const slots = shapes.collectShapeSlots(display.shape,bounds,40);
    const show = d=>slots.map(slot=>{const face=model.resolveSlotFace(d,slot);return {item:face.item?.key??null,kind:face.kind,key:model.resolveSlotFaceKey(d,slot)};});
    cases.push({explore,layer,look,bounds,center,view,slots,display:{start:display.startSlotKey,offset:display.wrapOffset,reserved:display.reservedPerBlock,faces:show(display),
        masked:show({...display,hiddenKeys:new Set(['key-0','key-4'])}),
        range:display.finite?finite.resolveFiniteCameraRange({finite:display.finite,itemCount:items.length,view,seamWidth:300}):null},
        updates:[updates.decideDataUpdate(display,{...layer}),updates.decideDataUpdate(display,{...layer,items:items.slice(1)}),updates.decideDataUpdate(display,{...layer,wall:{...layer.wall,filterKey:'other'}})]});
}
const removals = [[['a','b','c'],['a','c']],[['a','b','c'],['c','a']],[['a','b','c'],['a','x','c']],[['a','a','b'],['a','b']]].map(([a,b])=>{
    const result=removal.detectRemovedEntries(a.map(key=>({key})),b.map(key=>({key})));
    return {before:a,after:b,result:result?[...result]:null};
});
// Serialize sets intentionally rather than JSON silently replacing them with {}.
const out={baseline,cases,removals};
fs.writeFileSync(path.join(__dirname,'../test/fixtures/display_reference.json'),JSON.stringify(out,(_,v)=>v instanceof Set?[...v]:v,2)+'\n');
console.log('Exported twelve original display projections and four removal cases.');

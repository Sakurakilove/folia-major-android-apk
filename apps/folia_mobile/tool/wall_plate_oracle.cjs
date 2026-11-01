const vm = require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
const babel=require('@babel/core');
const {sourceText,load}=require('./original_source.cjs');

// Execute original backing/track functions without mounting their unrelated React host.
function evaluate(source,globals,names) {
    const code=babel.transformSync(stripTypeScriptTypes(source,{mode:'transform'}),{
        configFile:false,babelrc:false,plugins:[()=>({visitor:{ImportDeclaration(p){p.remove();},
            ExportNamedDeclaration(p){p.replaceWith(p.node.declaration);}}})]}).code;
    vm.runInNewContext(code+`\nglobalThis.result={${names.join(',')}};`,globals);
    return globals.result;
}
module.exports=()=>{
    const slots=load('src/components/wall/wallSlots.ts'),seam=load('src/components/wall/seamPlan.ts'),
        metrics={cellSize:128,gap:8},
        plates=evaluate(sourceText('src/library/suites/bravais/bravaisBlockPlate.ts'),
            {...slots,...seam,BRAVAIS_METRICS:metrics},['getPlateFrame','disjointRects','buildPlatePath']);
    const plateCases=[];
    for (const column of [-2,0,1]) for (const anchorX of [null,-4,1628]) for (const width of [1632,1856]) {
        const frame=plates.getPlateFrame(column,-1,anchorX,{width,height:1088}),
            holes=[{x:frame.x-8,y:frame.y-20,width:200.375,height:290.625},
                {x:frame.x+80.125,y:frame.y+90.125,width:315.375,height:184.875},
                {x:frame.x+300.5,y:frame.y+160.5,width:192.5,height:444.5}];
        plateCases.push({column,row:-1,anchorX,width,frame,holes,
            disjoint:plates.disjointRects(holes),d:plates.buildPlatePath(frame,holes)});
    }
    const motion=load('src/components/wall/wallReflowMotion.ts'),curve=motion.createWallReflowCurve(1624),
        source=sourceText('src/library/suites/bravais/useBravaisReflowDriver.ts'),
        tracks=evaluate(source.slice(source.indexOf('const rectOf'),source.indexOf('const writeTileRect')),
            {BRAVAIS_REFLOW_MS:curve.durationMs,bravaisReflowEase:curve.ease,
                BRAVAIS_BLOCK_SHAPE:{},shapeSlotFromKey:(_shape,key)=>{
                    const a=slots.parseWallSlotKey(key);return a?slots.getWallSlot(a.column,a.row,a.slotIndex,metrics):null;
                }},['planReflowTracks','sampleReflowTrack']);
    let current=new Map(),previous=new Map();
    const operations=[];
    for (const [kind,time,index] of [['target',0,1],['sample',100],['target',120,3],
        ['sample',200],['sample',1000],['target',1010,null],['sample',1200],['sample',2000]]) {
        if (kind==='target') {
            const next=new Map(index===null?[]:slots.layoutFocusedBlock(0,0,index,metrics).map(s=>[s.key,s]));
            current=tracks.planReflowTracks(current,previous,next,time);previous=next;
        }
        const rects=new Map([...previous].map(([k,r])=>[k,{x:r.x,y:r.y,width:r.width,height:r.height}]));
        for (const [key,track] of current) {
            rects.set(key,tracks.sampleReflowTrack(track,time));
            if (time-track.start>=curve.durationMs) current.delete(key);
        }
        operations.push({kind,time,index:index??null,rects:[...rects],animating:current.size>0});
    }
    return {plateCases,reflowOperations:operations};
};

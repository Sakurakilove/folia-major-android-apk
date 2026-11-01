const fs = require('node:fs');
const path = require('node:path');
const { baseline, load } = require('./original_source.cjs');

// One focused contract for original wall gears/ranks, finite bounds, repeating queue seats and pan curves.
const base = 'src/components/wall/';
const blocks = load(base + 'blockTemplates.ts'), slots = load(base + 'wallSlots.ts'),
    reserved = load(base + 'blockReservedSlots.ts'), finite = load(base + 'finiteWall.ts'),
    seam = load(base + 'seamPlan.ts'), lattice = load(base + 'layout.ts'),
    viewModel = load(base + 'wallView.ts'), pinch = load(base + 'wallPinch.ts'),
    pan = load(base + 'wallPanMotion.ts'), flip=load(base+'flipPlan.ts'),
    start=load(base+'startTile.ts'),frameModel=load('src/library/suites/bravais/bravaisFrame.ts'),
    wave=load('src/library/suites/bravais/bravaisWallWave.ts'),reflow=load(base+'wallReflowMotion.ts');
const blockCases = [], finiteCases = [], latticeCases = [], viewCases = [],frameCases=[],transitionCases=[],wrapCases=[];
for (const [column, row] of [[0,0],[-1,-1],[1,-3],[-7,15],[20,-11],[2147483647,-2147483648]]) {
    const metrics = {cellSize:128,gap:8};
    blockCases.push({column,row,metrics,template:blocks.getBlockTemplate(column,row),
        shuffle:reserved.getBlockSlotShuffle(column,row),
        slots:slots.getBlockSlots(column,row,metrics),
        reflows:Array.from({length:12},(_,i)=>slots.layoutFocusedBlock(column,row,i,metrics))});
}
for (const count of [0,1,13,217]) for (const width of [390,1440]) {
    const metrics={cellSize:128,gap:8}, view={width,height:844,scale:width<640?.52:.76,lineX:width*.47},
        origin={x:-16,y:389}, input={itemCount:count,reservedPerBlock:3,metrics,view,origin,startSlotKey:'0,0,1'},
        plan=finite.planFiniteWall(input), content=finite.getRankedContentBounds(plan.order,count);
    finiteCases.push({input,world:finite.getFiniteWallBlocks(input), order:plan.order.map(s=>s.key),content,
        range:finite.getFiniteCameraRange({contentBounds:content,anchor:origin,view,seamWidth:120}),
        seam:seam.blockSeamPlan({cameraX:origin.x,openWidth:300,view,metrics}),
        geometry:seam.getSeamGeometry({anchorX:-4,cameraX:origin.x,openWidth:300,view}),
        offsets:seam.getSeamSplitOffsets(120,view.scale,metrics)});
    const geometry=lattice.getLatticeGeometry(count,metrics),bounds={left:-2100,right:1500,top:-1400,bottom:1300},
        nearest=lattice.locateNearestInstance(geometry,count,count-1,{x:-3000,y:815},metrics);
    latticeCases.push({count,metrics,bounds,geometry,layout:lattice.layoutLattice(geometry,count,bounds,300,metrics),nearest,
        expanded:nearest?[...lattice.layoutExpandedBlock(geometry,count,nearest,metrics)]:[]});
    const camera={x:-397.25,y:153.7,scale:view.scale}, center=viewModel.viewCenterFromCamera(camera,view),
        pair=pinch.wallTouchPair([{x:100,y:200},{x:200,y:300}]), next=pinch.wallTouchPair([{x:25,y:190},{x:350,y:500}]);
    viewCases.push({view,camera,center,bounds:viewModel.getViewWorldBounds(center,view,{seamWidth:120,overscan:300}),
        pair,next,pinch:pinch.pinchWallCamera(camera,pair,next)});
}
for (const deg of [0,-3,-10]) for (const anchorX of [null,-4,1628]) for (const width of [390,1440]) {
    const view={width,height:844,scale:width<640?.52:.76},center={x:-200,y:480},
        input={view,center,anchorX,openWidth:320,contentWidth:520,hidden:false,poster:deg!==0,tiltDeg:deg},
        frame=frameModel.computeBravaisFrame(input);
    frameCases.push({input,frame,reach:frameModel.getTiltReach(view,frame.tilt),
        safe:frameModel.posterSafeArea({width:520,height:844,deg}),
        opening:frameModel.planPosterOpening({center,view,width:520})});
}
const transitionMetrics={cellSize:128,gap:8},transitionSlots=slots.collectWallSlots({left:-2400,right:2600,top:-1600,bottom:1700},transitionMetrics);
const changes=transitionSlots.map((slot,index)=>({slot,from:index%5===0?'same':'old',to:index%5===0?'same':index%7===0?null:'new'}));
for (const origin of [{kind:'point',x:-4,y:200},{kind:'seam-edges',x:-4}]) for (const maxTiles of [0,12,400]) {
    const visible={left:-1700,right:1800,top:-1200,bottom:1300},viewport={left:-800,right:900,top:-600,bottom:700};
    transitionCases.push({changes,origin,maxTiles,visible,viewport,metrics:transitionMetrics,
        flip:flip.planFlip({changes,origin,visible,metrics:transitionMetrics,maxTiles}),
        wave:wave.planWallWave({changes,viewport,visible,metrics:transitionMetrics,maxTiles})});
}
for (const count of [0,1,13,217]) for (const reservedPerBlock of [0,3,6]) {
    const address={column:-3,row:5,slotIndex:7},offset=start.getStartWrapOffset(address,count,reservedPerBlock);
    wrapCases.push({count,reservedPerBlock,address,offset,period:start.getWrapPeriod(count,reservedPerBlock),
        indices:transitionSlots.slice(0,24).map(slot=>({slot,index:start.getInfiniteSlotItem(slot,count,offset,reservedPerBlock)}))});
}
const reflowCases=[1,128,816,1632].map(distance=>{const curve=reflow.createWallReflowCurve(distance);return {
    distance,duration:curve.durationMs,css:curve.css,samples:[0,.01,.1,.25,.5,.75,.99,1].map(p=>({p,value:curve.ease(p)}))};});
const classify=pan.createWallWheelClassifier(), wheelCases=[];
for (const [deltaX,deltaY,timeStamp,deltaMode,shiftKey] of
    [[0,100,0,0,false],[0,20,16,0,false],[0,120,32,0,false],[0,-50,300,0,true],[1,2,310,1,false],[2,0,500,2,false]]) {
    const sample={deltaX,deltaY,timeStamp,deltaMode,shiftKey};
    wheelCases.push({sample,source:classify(sample),delta:pan.wallWheelDelta(sample,844)});
}
const wheelSteps=[0,1,16.6666666667,50,120,-2].map(dt=>({dt,pending:{x:48,y:-160},...pan.stepWallWheel({x:48,y:-160},dt)}));
(async()=>{
    const {inertia}=await import('motion-dom');
    const inertiaCases=[];
    for (const options of [{velocity:4000,power:.3,timeConstant:280,restDelta:.5},
        {velocity:-278,power:.3,timeConstant:280,restDelta:.5},
        {velocity:50,min:-20,max:30},{velocity:90,min:10,max:30},
        {velocity:300,min:-10,max:90,bounceStiffness:150,bounceDamping:18}]) {
        const gen=inertia({keyframes:[0,50],...options}),times=[0,1,16,33,90,180,300,600,1200,2400,4000,33];
        inertiaCases.push({options,samples:times.map(t=>({t,...gen.next(t)}))});
    }
    fs.writeFileSync(path.join(__dirname,'../test/fixtures/wall_reference.json'),JSON.stringify({baseline,
        scope:'Original pure geometry/input math only; not home UI, artwork, gesture timing, pixels or power acceptance.',
        blockCases,finiteCases,latticeCases,viewCases,wheelCases,wheelSteps,inertiaCases,frameCases,transitionCases,wrapCases,reflowCases,
        pointer:require('./wall_pointer_oracle.cjs')(),plates:require('./wall_plate_oracle.cjs')()})+'\n');
    console.log('Generated original wall geometry, wheel and inertia reference.');
})();

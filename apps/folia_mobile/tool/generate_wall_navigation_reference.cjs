const fs=require('node:fs');
const path=require('node:path');
const Module=require('node:module');
const babel=require('@babel/core');
const commonjs=require('@babel/plugin-transform-modules-commonjs');
const crypto=require('node:crypto');
const {baseline,load,sourceText,root}=require('./original_source.cjs');

// Actual original directional/layout-memory/store functions; no browser mount or duplicated scoring/parser implementation.
const paths=['src/components/wall/wallNavigation.ts','src/library/suites/bravais/bravaisNavigation.ts',
    'src/library/suites/bravais/bravaisLayoutMemory.ts','src/library/suites/bravais/bravaisStageStore.ts','src/library/suites/bravais/entry.ts'],
    navigation=load(paths[1]),shared=load(paths[0]),shapes=load('src/library/suites/bravais/bravaisWallShape.ts'),store=load(paths[3]),
    prefix=sourceText(paths[4]).match(/export const BRAVAIS_LAYOUT_STORAGE_PREFIX = '([^']+)'/)[1],
    memoryModule=new Module(path.join(root,paths[2]));
memoryModule.filename=path.join(root,paths[2]);memoryModule.paths=Module._nodeModulePaths(path.dirname(memoryModule.filename));
const requireOriginal=memoryModule.require.bind(memoryModule);
memoryModule.require=request=>request==='./entry'?{BRAVAIS_LAYOUT_STORAGE_PREFIX:prefix}:requireOriginal(request);
memoryModule._compile(babel.transformSync(Module.stripTypeScriptTypes(sourceText(paths[2]),{mode:'transform'}),{plugins:[commonjs],configFile:false,babelrc:false}).code,memoryModule.filename);
const memory=memoryModule.exports,sections=[{key:'first',heading:'First',entries:Array.from({length:5},(_,index)=>({index,kind:'song'}))},
    {key:'second',heading:'Second',entries:Array.from({length:9},(_,i)=>({index:i+5,kind:'album'}))}],
    shapeInput={sections,origin:{column:1,row:-1}},allShapes=[shapes.BRAVAIS_BLOCK_SHAPE,shapes.createExploreShape(sections,shapeInput.origin)],moves=[];
for(let shapeIndex=0;shapeIndex<allShapes.length;shapeIndex++) for(const [column,row] of [[0,0],[-2,1]]) for(const direction of ['up','down','left','right']) for(const mode of ['dense','grown','ring3','empty']) {
    const shape=allShapes[shapeIndex],from=shape.blockSlots(column,row)[0],grown=mode==='grown'?shape.grownBlock(column,row,from.slotIndex):null,
        overrides=new Map((grown||[]).map(slot=>[slot.key,slot])),
        target=mode==='ring3'?{column:column+(direction==='left'?-3:direction==='right'?3:0),row:row+(direction==='up'?-3:direction==='down'?3:0)}:null,
        hasContent=slot=>mode!=='empty'&&shape.headingAt(slot)===null&&(!target||(slot.column===target.column&&slot.row===target.row)),
        result=navigation.findAdjacentSlot(from,direction,{shape,hasContent,drawn:slot=>overrides.get(slot.key)||slot});
    moves.push({shape:shapeIndex,column,row,seat:from.slotIndex,direction,mode,target,result:result?.key??null});
}
const raws=['','null','[]','{}','true','0','"text"','{broken',
    '{"center":{"x":1,"y":2},"anchorX":10,"startSlotKey":"-1,2,3","focusSlotKey":"0,0,1"}',
    '{"center":{"x":1e999,"y":3},"anchorX":1e999,"startSlotKey":false,"focusSlotKey":0}',
    '{"center":[1,2],"anchorX":"2","startSlotKey":"","shapeKind":"unknown"}',
    '{"center":{"x":-0,"y":22.5},"anchorX":-900,"startSlotKey":"0x1,0b10,0o0","focusSlotKey":"f","shapeKind":"explore"}',
    '{"center":{"x":9007199254740993,"y":-9},"anchorX":0,"startSlotKey":"1e1, -2,0","shapeKind":"blocks"}',
    '{"startSlotKey":"\\u00851,0,0","shapeKind":"explore"}',
    '{"startSlotKey":" \\ufeff1, 2e0, -0 ","shapeKind":"explore"}',
    '{"startSlotKey":"-0x1,2,0","shapeKind":"explore"}'],
    parsed=raws.map(raw=>({raw,result:memory.parseBravaisLayoutRecord(raw)})),fits=[];
for(const item of parsed) if(item.result) for(let shape=0;shape<allShapes.length;shape++) fits.push({raw:item.raw,shape,result:memory.fitBravaisLayoutToShape(item.result,allShapes[shape])});
const layers=[{key:'home'},{key:'album'},{key:'album'},{key:'artist'}],operations=[
    {op:'register',slot:'home',token:1,layer:0},{op:'register',slot:'home',token:1,layer:0},
    {op:'register',slot:'top',token:2,layer:1},{op:'release',slot:'top',token:1},
    {op:'register',slot:'top',token:3,layer:2},{op:'release',slot:'top',token:2},
    {op:'set',origin:{fromLayerKey:'album',slotKey:null}},{op:'take',from:'wrong'},
    {op:'set',origin:{fromLayerKey:'album',slotKey:'0,0,0'}},{op:'take',from:'album'},
    {op:'take',from:'album'},{op:'set',origin:null},{op:'set',origin:null},{op:'release',slot:'top',token:3},
    {op:'release',slot:'home',token:1}],stage=[];
store.useBravaisStageStore.setState({home:null,top:null,pendingOrigin:null});
const snapshot=s=>({home:s.home?{token:s.home.token,layer:layers.indexOf(s.home.layer)}:null,top:s.top?{token:s.top.token,layer:layers.indexOf(s.top.layer)}:null,pendingOrigin:s.pendingOrigin});
for(const input of operations) {
    const before=store.useBravaisStageStore.getState();let taken=null;
    if(input.op==='register')store.registerBravaisLayer(input.slot,input.token,layers[input.layer]);
    else if(input.op==='release')store.releaseBravaisLayer(input.slot,input.token);
    else if(input.op==='set')store.setBravaisPendingOrigin(input.origin);
    else taken=store.takeBravaisPendingOrigin(input.from);
    const state=store.useBravaisStageStore.getState();stage.push({input,state:snapshot(state),same:state===before,taken});
}
const current=[];
for(const depth of [-1,0,1,2.5])for(const home of [false,true])for(const top of [false,true])for(const previous of [null,3]) {
    const result=store.resolveCurrentLayer({depth,home:home?{token:1,layer:layers[0]}:null,top:top?{token:2,layer:layers[1]}:null,previous:previous===null?null:layers[previous]});
    current.push({input:{depth,home,top,previous},result:{owned:result.owned,layer:result.layer===null?null:layers.indexOf(result.layer)}});
}
const nearest=[{items:[],point:{x:0,y:0}},
    {items:[{x:-20,y:-20,width:10,height:10},{x:10,y:10,width:10,height:10}],point:{x:0,y:0}},
    {items:[{x:0,y:0,width:100,height:100},{x:80,y:20,width:100,height:100},{x:-100,y:100,width:300,height:30}],point:{x:140,y:100}}]
    .map(input=>({input,result:input.items.indexOf(shared.findNearestInstance(input.items,input.point))}));
fs.writeFileSync(path.join(__dirname,'../test/fixtures/wall_navigation_reference.json'),JSON.stringify({baseline,scope:'Original pure selection/session/store outputs; keyboard routing, complete stage and device acceptance remain pending.',
    sourceHashes:Object.fromEntries(paths.map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),prefix,shapeInput,moves,nearest,parsed,fits,stage,current,
    tokens:[store.takeBravaisLayerToken(),store.takeBravaisLayerToken(),store.takeBravaisLayerToken()]},null,2)+'\n');
console.log(`Exported ${moves.length} directional, ${parsed.length} parser, ${stage.length} stage and ${current.length} current-layer observations.`);

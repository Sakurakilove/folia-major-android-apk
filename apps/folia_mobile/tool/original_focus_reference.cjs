const Module=require('node:module');
const path=require('node:path');
const babel=require('@babel/core');
const commonjs=require('@babel/plugin-transform-modules-commonjs');
const {root,load,sourceText}=require('./original_source.cjs');

// Execute the actual original hook with deterministic state/ref/memo commits. The explicit commit separates the event-time refs from the next render's reflowRef.
module.exports=function focusReference(){
    const source='src/library/suites/bravais/useBravaisFocus.ts',file=path.join(root,source),module=new Module(file),cells=[];
    let cursor=0,api;
    const react={
        useState(initial){const i=cursor++;if(!cells[i])cells[i]={value:typeof initial==='function'?initial():initial};return [cells[i].value,value=>{cells[i].value=value;}];},
        useRef(value){const i=cursor++;return cells[i]??=( {current:value} );},
        useMemo(run,deps){const i=cursor++,old=cells[i];if(!old||deps.some((v,n)=>v!==old.deps[n]))cells[i]={value:run(),deps};return cells[i].value;},
        useCallback:run=>run,
    };
    module.filename=file;module.paths=Module._nodeModulePaths(path.dirname(file));const required=module.require.bind(module);
    module.require=request=>request==='react'?react:required(request);
    module._compile(babel.transformSync(Module.stripTypeScriptTypes(sourceText(source),{mode:'transform'}),{plugins:[commonjs],configFile:false,babelrc:false}).code,file);
    const shape=load('src/library/suites/bravais/bravaisWallShape.ts').BRAVAIS_BLOCK_SHAPE,slots=shape.blockSlots(0,0),
        frame={center:{x:200,y:150},view:{width:390,height:844,scale:.52},anchorX:-4,openWidth:300,targetOpenWidth:420,contentWidth:300,hidden:false,poster:false,tiltDeg:-10},
        frameRef={current:{...frame,view:null}},notes=[],tweens=[],input={frameRef,getShape:()=>shape,getBottomInset:()=>180,onFocusEntry:key=>notes.push(key),tweenTo:center=>tweens.push(center)},
        render=()=>{cursor=0;api=module.exports.useBravaisFocus(input);},
        operations=[{op:'reveal',seat:0},{op:'view-ready'},
            {op:'focus',seat:1,reveal:true},{op:'expand',seat:0,centered:true},{op:'focus',seat:2,reveal:true},{op:'commit'},
            {op:'focus',seat:3,reveal:true},{op:'focus',seat:3,reveal:true},{op:'expand',seat:2},{op:'focus',seat:1,reveal:true},{op:'commit'},
            {op:'collapse'},{op:'focus',seat:2,reveal:true},{op:'commit'},
            {op:'poster'},{op:'expand',seat:0,centered:true},{op:'commit'},{op:'reveal',seat:2,centered:true},
            {op:'focus',seat:null},{op:'collapse'},{op:'commit'}],steps=[];
    render();
    for(const command of operations){
        if(command.op==='view-ready')frameRef.current.view=frame.view;
        else if(command.op==='poster')frameRef.current.poster=true;
        else if(command.op==='commit')render();
        else if(command.op==='focus')api.focusSlot(command.seat===null?null:slots[command.seat],{reveal:!!command.reveal});
        else if(command.op==='expand')api.expand(slots[command.seat],{centered:!!command.centered});
        else if(command.op==='collapse')api.collapse();
        else api.reveal(api.drawnRect(slots[command.seat]),{centered:!!command.centered});
        const rect=r=>({x:r.x,y:r.y,width:r.width,height:r.height});
        steps.push({command,focused:api.focusedRef.current,expanded:api.expandedRef.current,notes:notes.length,tweens:tweens.length,
            lastNote:notes.at(-1)??null,lastTween:tweens.at(-1)??null,drawn:slots.slice(0,3).map(s=>rect(api.drawnRect(s)))});
    }
    return {source,frame,bottomInset:180,steps};
};

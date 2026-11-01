const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const babel = require('@babel/core');
const { sourceText, load } = require('./original_source.cjs');

// Drive the unchanged hook body with tiny DOM/React scheduling stubs; do not rewrite its gesture logic as the oracle.
module.exports = () => {
    const effects=[],callbacks=new Map(),handlers=new Map(),windowHandlers=new Map();
    let next=0,now=0;
    class Element {
        constructor(control=false,editable=false) { this.control=control;this.editable=editable;this.dataset={}; }
        closest(selector) { return this.control || (this.editable&&selector.includes('contenteditable')) ? this : null; }
        getBoundingClientRect() { return {left:0,top:0}; }
        setPointerCapture() {} releasePointerCapture() {} hasPointerCapture() { return true; }
        addEventListener(name,cb) { handlers.set(name,cb); }
        removeEventListener() {}
        contains() { return true; }
    }
    const container=new Element(), cameraRef={current:{x:0,y:0,scale:.52}},animationRef={current:null},
        writes=[],commits=[];
    const stopPan=()=>{animationRef.current?.stop();animationRef.current=null;};
    const sandbox={Element,Node:Element,Math,Boolean,
        useRef:value=>({current:value}),useCallback:callback=>callback,
        useEffect:callback=>effects.push(callback),
        runsOnAndroid:()=>true,
        requestUncappedAnimationFrame:cb=>{callbacks.set(++next,cb);return next;},
        cancelUncappedAnimationFrame:id=>callbacks.delete(id),
        ...load('src/components/wall/wallPanMotion.ts'),...load('src/components/wall/wallPinch.ts'),
        animate:(_from,_to,options)=>({stop:()=>{}}),
        window:{addEventListener(name,cb){windowHandlers.set(name,cb);},removeEventListener(){},setTimeout:()=>++next,clearTimeout(){}},
    };
    const stripped=stripTypeScriptTypes(sourceText('src/components/wall/useWallPointerPan.ts'),{mode:'transform'});
    const code=babel.transformSync(stripped,{configFile:false,babelrc:false,plugins:[()=>({visitor:{
        ImportDeclaration(p){p.remove();},ExportNamedDeclaration(p){p.replaceWith(p.node.declaration);},
    }})]}).code;
    vm.runInNewContext(code+'\nglobalThis.hook=useWallPointerPan;',sandbox);
    const pointer=sandbox.hook({applyCamera:(c,updateBounds=false)=>{cameraRef.current=c;writes.push({camera:c,updateBounds});},
        animationRef,stopPan,containerRef:{current:container},reducedMotion:false,overscan:300,
        bounds:{left:-1000000,right:1000000,top:-1000000,bottom:1000000},cameraRef,
        getWorldBounds:c=>({left:c.x,right:c.x+390,top:c.y,bottom:c.y+844}),
        viewportRef:{current:{width:390,height:844}},onScaleCommit:scale=>commits.push(scale)});
    effects.forEach(effect=>effect());
    const operations=[
        {kind:'down',id:1,x:100,y:100,t:0,touch:true},
        {kind:'move',id:1,x:106,y:100,t:10,touch:true},
        {kind:'move',id:1,x:108,y:100,t:20,touch:true},
        {kind:'move',id:1,x:140,y:165,t:40,touch:true},
        {kind:'up',id:1,x:140,y:165,t:180,touch:true},{kind:'click',keyboard:true},{kind:'click'},
        {kind:'down',id:2,x:70,y:150,t:200,touch:true},
        {kind:'down',id:3,x:200,y:350,t:202,touch:true,primary:false},
        {kind:'move',id:3,x:300,y:410,t:214,touch:true,primary:false},
        {kind:'move',id:2,x:40,y:100,t:215,touch:true},{kind:'tick',t:216},
        {kind:'up',id:3,x:300,y:410,t:220,touch:true,primary:false},{kind:'click'},
        {kind:'down',id:4,x:10,y:20,t:300},
        {kind:'move',id:4,x:25,y:40,t:310},{kind:'move',id:4,x:40,y:60,t:312},
        {kind:'tick',t:316},{kind:'move',id:4,x:50,y:80,t:320},
        {kind:'up',id:4,x:50,y:80,t:450},
        {kind:'down',id:5,x:5,y:5,t:500,touch:true,control:true},
        {kind:'move',id:5,x:60,y:80,t:515,touch:true},{kind:'up',id:5,x:60,y:80,t:620,touch:true},
        {kind:'wheel',dx:0,dy:100,t:700},{kind:'tick',t:716},{kind:'wheel',dx:0,dy:100,t:720},
        {kind:'tick',t:732},{kind:'wheel',dx:2,dy:4,t:740},{kind:'tick',t:748},
        {kind:'wheel',dx:0,dy:-50,t:1000,shift:true},{kind:'tick',t:1016},
        {kind:'wheel',dx:0,dy:30,t:1020,ctrl:true},{kind:'cancel',id:6,x:0,y:0,t:1030},
        {kind:'blur',t:1040},{kind:'tick',t:1060},
    ];
    const states=[];
    for (const op of operations) {
        now=op.t??now;
        const event={pointerId:op.id,clientX:op.x,clientY:op.y,timeStamp:now,button:0,
            pointerType:op.touch?'touch':'mouse',isPrimary:op.primary??true,target:new Element(op.control,op.editable),
            currentTarget:container,preventDefault(){},stopPropagation(){}};
        if (op.kind==='tick') { const pending=[...callbacks.values()];callbacks.clear();pending.forEach(cb=>cb(now)); }
        else if (op.kind==='click') pointer.onClickCapture({...event,detail:op.keyboard?0:1});
        else if (op.kind==='wheel') handlers.get('wheel')({...event,deltaX:op.dx,deltaY:op.dy,deltaMode:0,shiftKey:op.shift??false,ctrlKey:op.ctrl??false});
        else if (op.kind==='blur') { /* window listeners are recorded separately below */ windowHandlers.get('blur')?.(); }
        else pointer[{down:'onPointerDown',move:'onPointerMove',up:'onPointerUp',cancel:'onPointerCancel'}[op.kind]](event);
        states.push({writes:writes.length,camera:cameraRef.current,didDrag:pointer.didDragRef.current,commits:[...commits]});
    }
    stopPan();
    return {operations,states,writes,commits};
};

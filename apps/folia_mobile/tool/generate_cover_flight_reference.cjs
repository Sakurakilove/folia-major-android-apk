const fs=require('node:fs');
const path=require('node:path');
const Module=require('node:module');
const babel=require('@babel/core');
const commonjs=require('@babel/plugin-transform-modules-commonjs');
const crypto=require('node:crypto');
const {root,baseline,sourceText}=require('./original_source.cjs');

// Execute the fixed original functions with a discrete RAF/DOM adapter. This observes timing/geometry only, not fonts, GPU output or the final poster handoff.
const source='src/library/suites/bravais/bravaisCoverFlight.ts', text=sourceText(source),
    file=path.join(root,source), moduleUnderTest=new Module(file);
moduleUnderTest.filename=file;
moduleUnderTest.paths=Module._nodeModulePaths(path.dirname(file));
moduleUnderTest._compile(babel.transformSync(Module.stripTypeScriptTypes(text+
    '\nexport const observed={fly,drawnCoverSize,coverOffset,measureQuadWith};', {mode:'transform'}),
    {plugins:[commonjs],configFile:false,babelrc:false}).code,file);
const original=moduleUnderTest.exports.observed;
let now=0,serial=0,raf=new Map(),images=[];
global.performance={now:()=>now};
global.requestAnimationFrame=cb=>{const id=++serial;raf.set(id,cb);return id};
global.cancelAnimationFrame=id=>raf.delete(id);
global.document={documentElement:{dataset:{}},body:{appendChild:image=>images.push(image)},
    createElement:()=>({style:{},dataset:{},setAttribute(){},remove(){this.removed=true},
        animate(keyframes,options){const animation={keyframes,options};this.animation=animation;return animation}})};
function frame(at){now=at;const callbacks=[...raf.values()];raf.clear();callbacks.forEach(cb=>cb(now));}
function state(image,done,reads){
    const style=image.style,t=/translate\(([^p]+)px, ([^p]+)px\) rotate\(([^r]+)rad\) scale\(([^)]+)\)/.exec(style.transform),
        s=/^([^p]+)px ([^p]+)px 0 color-mix\(in srgb, (#[0-9a-f]+|transparent) ([^%]+)%, transparent\), ([^p]+)px ([^p]+)px ([^p]+)px rgba\(0,0,0,([^)]+)\)/.exec(style.boxShadow);
    return {quad:[+t[1],+t[2],parseFloat(style.width),parseFloat(style.height),+t[3]],scale:+t[4],
        hard:[+s[1],s[3],+s[4]/100],soft:[+s[5],+s[6],+s[7],+s[8]],
        done,reads,removed:!!image.removed,fade:image.animation?.options??null};
}
const from={center:{x:50,y:120},width:128,height:240,angle:3.05},
    initialTarget={center:{x:390,y:450},width:320,height:320,angle:-3.05},
    movedTarget={center:{x:320,y:410},width:340,height:280,angle:-2.9},cases=[];
for(const name of ['swap','wait','lost','stop','fade']){
    now=0;raf=new Map();images=[];let done=0,reads=0,target=initialTarget,lost=false,ready=false;
    const flight=original.fly({url:'https://example.com/cover.jpg',from,target:()=>target,duration:name==='fade'?560:640,
        shadow:{from:{offset:2,color:'#112233'},to:q=>({offset:q.width/40,color:'#aabbcc'})},
        landing:name==='fade'?'fade':'swap',ready:()=>{reads++;return ready},lost:()=>lost,onDone:()=>done++}),
        image=images[0],steps=[{at:0,op:'start',expected:state(image,done,reads)}];
    for(const at of [80,160,320,480,560,640,656,900,1160,1240,1256]){
        target=at>=320?movedTarget:initialTarget;
        if(at===480&&name==='lost')lost=true;
        if(at>=560&&name!=='wait')ready=true;
        frame(at);
        let op='frame';
        if(at===320&&name==='stop'){flight.stop();op='stop';}
        steps.push({at,op,target:target===movedTarget?'moved':'initial',lost,ready,expected:state(image,done,reads)});
        if(image.animation){now=at+image.animation.options.duration;image.animation.onfinish();steps.push({at:now,op:'fade-finish',expected:state(image,done,reads)});break;}
        if(image.removed)break;
    }
    cases.push({name,from,initialTarget,movedTarget,steps});
}
const sizes=[];
for(const size of ['cover','contain','auto','50%','24px auto','auto 75%','20px 80px','50% 40%,cover'])
    for(const [width,height] of [[128,240],[816,128]])sizes.push({size,width,height,result:original.drawnCoverSize(size,width,height)});
const offsets=[];
for(const token of [null,'center','left','top','right','bottom','25%','-10px','12.5px','auto'])
    for(const free of [-64,0,128])offsets.push({token,free,result:original.coverOffset(token??undefined,free)});
fs.writeFileSync(path.join(__dirname,'../test/fixtures/cover_flight_reference.json'),JSON.stringify({baseline,
    scope:'Original function traces with discrete RAF and DOM adapters; complete visual/device acceptance remains pending.',
    sourceHashes:{[source]:crypto.createHash('sha256').update(text).digest('hex')},cases,sizes,offsets},null,2)+'\n');
console.log(`Exported ${cases.length} original cover-flight traces, ${sizes.length} sizes and ${offsets.length} positions.`);

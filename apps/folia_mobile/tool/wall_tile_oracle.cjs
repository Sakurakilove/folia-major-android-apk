const vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
const babel=require('@babel/core');
const {sourceText,load}=require('./original_source.cjs');

// Run the original BravaisTile layout effects and refs across content changes; WAAPI is a timed completion stub, not a pixel oracle.
module.exports=()=>{
    const hooks=[],animations=[];let cursor=0,now=0,dirty=false,effects=[],props,result;
    const face={animate:(keyframes,options)=>{
        const animation={keyframes,options,start:now,cancelled:false,finished:false,
            cancel(){this.cancelled=true;}};animations.push(animation);return animation;
    }};
    const look=load('src/library/suites/bravais/bravaisLook.ts'),
        constants=load('src/library/suites/bravais/bravaisConstants.ts'),
        wave=load('src/library/suites/bravais/bravaisWallWave.ts');
    const sandbox={...look,...constants,...wave,countRender(){},performance:{now:()=>now},
        useRef:value=>{
            const index=cursor++;
            return hooks[index]??(hooks[index]={current:index===0?face:value});
        },
        useState:value=>{
            const index=cursor++,cell=hooks[index]??(hooks[index]={value});
            return [cell.value,next=>{if (!Object.is(cell.value,next)) {cell.value=next;dirty=true;}}];
        },
        useLayoutEffect:(callback,deps)=>{
            const index=cursor++,old=hooks[index];
            if (!old||!deps||deps.some((v,i)=>!Object.is(v,old.deps?.[i]))) effects.push({index,callback,deps});
        },
    };
    const display=sourceText('src/library/suites/bravais/bravaisDisplay.ts'),
        transitionStart=display.indexOf('export const resolveTileTransition'),
        transition=display.slice(transitionStart,display.indexOf('/**',transitionStart+10)).replace('export ',''),
        source=sourceText('src/library/suites/bravais/BravaisTile.tsx'),
        constantsBody=source.slice(source.indexOf('const rotation'),source.indexOf('/** 窗上按下鼠标')),
        keyBody=source.slice(source.indexOf('const faceKeyOf'),source.indexOf('function BravaisTile')),
        body=source.slice(source.indexOf('function BravaisTile'),source.indexOf('    // 透着的磁贴不画封面'));
    const code=transition+'\n'+constantsBody+'\n'+keyBody+'\n'+body+'return {face,shownKey,transition};}\nglobalThis.render=BravaisTile;';
    vm.runInNewContext(babel.transformSync(stripTypeScriptTypes(code,{mode:'transform'}),
        {configFile:false,babelrc:false}).code,sandbox);
    function commit() {
        for (let guard=0;guard<20;guard++) {
            dirty=false;cursor=0;effects=[];result=sandbox.render(props);
            const pending=effects;
            pending.forEach(e=>hooks[e.index]?.cleanup?.());
            pending.forEach(e=>{hooks[e.index]={deps:e.deps,cleanup:e.callback()};});
            if (!dirty) return;
        }
        throw Error('Original tile effects failed to settle');
    }
    function advance() {
        for (let guard=0;guard<20;guard++) {
            const finished=animations.filter(a=>!a.cancelled&&!a.finished&&
                now>=a.start+(a.options.delay??0)+a.options.duration);
            if (!finished.length) return;
            finished.forEach(a=>{a.finished=true;a.onfinish?.();});if (dirty) commit();
        }
        throw Error('Original WAAPI completion failed to settle');
    }
    props={slotKey:'0,0,0',rect:{x:0,y:0,width:400,height:300},item:{key:'A',title:'A'},
        kind:'content',seeThrough:false,reducedMotion:false,entrance:null};commit();
    const operations=[{kind:'target',time:0,key:'B',token:1,delay:20},{kind:'frame',time:15},{kind:'frame',time:80},
        {kind:'target',time:90,key:'C',token:1,delay:20},{kind:'frame',time:260},
        {kind:'target',time:280,key:'C',title:'C2',token:1,delay:20},
        {kind:'target',time:300,key:'D',token:2,delay:40,waveInDelay:700},{kind:'frame',time:500},
        {kind:'frame',time:620},{kind:'target',time:650,key:'E',token:2,delay:40,waveInDelay:700},
        {kind:'frame',time:1050},{kind:'target',time:1100,key:'F',token:3,delay:0,reduced:true},
        {kind:'frame',time:1190},{kind:'frame',time:1280},
        {kind:'entrance',time:1400,token:4,startedAt:1300,until:2200},
        {kind:'target',time:1450,key:'F',title:'F3',token:3,delay:0,reduced:true},{kind:'frame',time:1720},
        {kind:'entrance',time:1900,token:5,startedAt:1700,until:2200,mountsOnly:true},{kind:'frame',time:2000}];
    const states=[];
    function animationKind(a) {
        if (!a) return null;
        const first=a.keyframes[0],last=a.keyframes.at(-1);
        if (first.transform?.includes('perspective')) return last.transform.includes('rotateY(0deg)')?'flipIn':'flipOut';
        if (first.transform||last.transform) return first.transform==='none'?'waveOut':'waveIn';
        return first.opacity===1?'fadeOut':a.options.duration===180?'entranceFade':'fadeIn';
    }
    for (const op of operations) {
        now=op.time;
        if (op.kind==='target') {
            props={...props,item:{key:op.key,title:op.title??op.key},reducedMotion:op.reduced??false,
                step:{token:op.token,to:op.key,delay:op.delay,direction:1,
                    ...(op.waveInDelay===undefined?{}:{wave:{inDelay:op.waveInDelay}})}};commit();
        } else if (op.kind==='entrance') {
            props={...props,entrance:{...op,corner:{left:0,top:0},reduced:false}};commit();
        } else advance();
        const active=animations.filter(a=>!a.cancelled&&!a.finished).at(-1);
        states.push({key:result.face.item?.key??null,title:result.face.item?.title??null,flight:animationKind(active)});
    }
    return {operations,states};
};

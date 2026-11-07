const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const babel = require('@babel/core');
const { sourceText, load } = require('./original_source.cjs');

// Execute the original seam content effects. Timed WAAPI completion stubs verify effect identity/commit order, not browser pixels or real focus restoration.
module.exports = () => {
    const hooks = [], animations = []; let cursor = 0, now = 0, dirty = false, effects = [], props, result;
    class Element {
        constructor() { this.attributes = new Map(); }
        contains() { return false; }
        querySelector() { return null; }
        setAttribute(k,v) { this.attributes.set(k,v); }
        removeAttribute(k) { this.attributes.delete(k); }
        animate(keyframes,options) {
            const a = { keyframes, options, start:now, cancelled:false, finished:false, cancel() { this.cancelled = true; } };
            animations.push(a); return a;
        }
    }
    const element = new Element(), motion = load('src/library/suites/bravais/bravaisSeamMotion.ts');
    const effect = (callback,deps) => {
        const index = cursor++, old = hooks[index];
        if (!old || !deps || deps.some((v,i)=>!Object.is(v,old.deps?.[i]))) effects.push({index,callback,deps});
    };
    const sandbox = {...motion, HTMLElement:Element, document:{activeElement:null,body:{}},
        resolveSeamContentIdentity:layer=>layer.key, isFocusDropped:()=>true,
        useRef:value=>{ const index=cursor++; return hooks[index]??(hooks[index]={current:value}); },
        useState:value=>{ const index=cursor++,cell=hooks[index]??(hooks[index]={value});
            return [cell.value,next=>{if (!Object.is(cell.value,next)) {cell.value=next;dirty=true;}}]; },
        useLayoutEffect:effect,useEffect:effect,
    };
    const source = sourceText('src/library/suites/bravais/useBravaisSeam.ts');
    const body = source.slice(source.indexOf('    // 缝里的内容：'),source.indexOf('    // 排版宽度跟着'));
    const code = `function seam({layer,targetVariant,contentRef,reducedTransitions}) {
        const [rendered,setRendered]=useState({variant:targetVariant,layer});
        ${body}
        return {key:renderedLayer?.key??null,revision:renderedLayer?.revision??null,variant:rendered.variant,leaving:flipMode==='flip'};
    } globalThis.render=seam;`;
    vm.runInNewContext(babel.transformSync(stripTypeScriptTypes(code,{mode:'transform'}),{configFile:false,babelrc:false}).code,sandbox);
    function commit() {
        for(let guard=0;guard<20;guard++) {
            dirty=false;cursor=0;effects=[];result=sandbox.render(props);
            const pending=effects;
            pending.forEach(e=>hooks[e.index]?.cleanup?.());
            pending.forEach(e=>{hooks[e.index]={deps:e.deps,cleanup:e.callback()};});
            if(!dirty) return;
        }
        throw Error('Original seam effects did not settle');
    }
    function advance() {
        for(let guard=0;guard<20;guard++) {
            const completed=animations.filter(a=>!a.cancelled&&!a.finished&&now>=a.start+(a.options.delay??0)+a.options.duration);
            if(!completed.length) return;
            completed.forEach(a=>{a.finished=true;a.onfinish?.();}); if(dirty) commit();
        }
        throw Error('Original seam completions did not settle');
    }
    props={layer:{key:'A',revision:1},targetVariant:'home',contentRef:{current:element},reducedTransitions:false};commit();
    const operations=[{time:0,key:'B',variant:'full'},{time:80,key:'C',variant:'panel'},{time:160},
        {time:180,key:'C',variant:'panel',revision:2},{time:220,key:'D',variant:'form'},
        {time:250,key:'C',variant:'panel',revision:3},{time:300,key:null,variant:'none'},
        {time:320,key:'E',variant:'full',reduced:true},{time:410},
        {time:430,key:'F',variant:'form',reduced:true},{time:460,key:'G',variant:'panel',reduced:true},{time:520},
        {time:550,key:null,variant:'none',reduced:true},{time:560,key:'H',variant:'home'},{time:610},
        {time:630,key:'I',variant:'spine',hasElement:false},{time:650,key:'J',variant:'full'},{time:810},{time:1050}];
    const states=[];
    for(const op of operations) {
        now=op.time;
        if('key' in op) {
            props={...props,layer:op.key===null?null:{key:op.key,revision:op.revision??1},targetVariant:op.variant,
                reducedTransitions:op.reduced??false,contentRef:op.hasElement===false?{current:null}:{current:element}};
            // A real contentRef is stable across the retained element's lifetime.
            props.contentRef = hooks.contentRef??(hooks.contentRef={current:element});
            props.contentRef.current=op.hasElement===false?null:element;
            commit();
        } else advance();
        const active=animations.filter(a=>!a.cancelled&&!a.finished).at(-1);
        const first=active?.keyframes[0], phase=!active?null:first.transform?(first.transform.includes('(0deg)')?'flipOut':'flipIn'):
            first.opacity===1?'fadeOut':'fadeIn';
        states.push({...result,phase});
    }
    return {operations,states};
};

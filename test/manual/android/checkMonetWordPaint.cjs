// Compare actual old/new word components' paint values without a browser; pass a mobile.16 source file.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '../../..');
const projectRequire = require('node:module').createRequire(path.join(root, 'package.json'));
const babel = projectRequire('@babel/core');
const baseline = process.argv[2];
if (!baseline || !fs.existsSync(baseline)) throw new Error('Usage: node checkMonetWordPaint.cjs <mobile.16 MonetRailTokens.tsx>');
const folder=path.join(root, 'src/components/visualizer/monet');
const model=fs.readFileSync(folder+'/monetLyricsModel.ts','utf8');
const helpers=model.slice(model.indexOf('export const resolveMonetSweepEdgeSoftness'),model.indexOf('/** Builds a stable display-token'));
async function load(path){
 const original=fs.readFileSync(path,'utf8');
 const word=original.slice(original.indexOf('const MonetWordSweep:')).replace('const MonetWordSweep:','export const MonetWordSweep:');
 const imports=`import React,{useMemo,useRef,useLayoutEffect} from 'react'; import {motion,motionValue,useTransform} from 'framer-motion'; import {resolveMonetFillWidth,resolveMonetGlow} from './monetLyricMotion'; import {mixColors,colorWithAlpha} from '../colorMix'; import {resolveMonetSweepEdgeSoftness,resolveMonetSweepEnd,resolveMonetWordStatus,measureMonetGraphemeOffsets} from './monetLyricsModel'; const STILL_TIME=motionValue(0);`;
 const ctx={exports:{},module:{exports:{}},effects:[]};ctx.exports=ctx.module.exports;
 const {transformSync}=await import(projectRequire.resolve('rolldown/experimental'));
 const compile=code=>babel.transformSync(transformSync('word.tsx',code,{jsx:{runtime:'classic'}}).code,{plugins:[projectRequire('@babel/plugin-transform-modules-commonjs')],configFile:false,babelrc:false}).code;
 const evaluate=(code,requires={})=>{const c={exports:{},module:{exports:{}},require:p=>requires[p]};c.exports=c.module.exports;vm.runInNewContext(compile(code),c);return c.exports;};
 // Hooks and JSX bind to the component host so layout effects run after every ref has attached.
 const React={createElement(type,props,...children){const node={type,props:props||{},children,style:{...(props?.style||{})}};if(props?.ref)props.ref.current=node;return node;}};
 const motion={span:'span'};const motionValue=v=>({get:()=>v});const useTransform=(source,fn)=>({get:()=>fn(source.get())});
 const requires={'react':{__esModule:true,default:React,useMemo:f=>f(),useRef:()=>({current:null}),useLayoutEffect:f=>ctx.effects.push(f)},'framer-motion':{motion,motionValue,useTransform},'./monetLyricMotion':evaluate(fs.readFileSync(folder+'/monetLyricMotion.ts','utf8')),'../colorMix':evaluate(fs.readFileSync(folder+'/../colorMix.ts','utf8'),{'./textMeasureCache':{rememberBounded:(m,k,v)=>{m.set(k,v);return v;}}}),'./monetLyricsModel':evaluate(helpers+'\nexport const measureMonetGraphemeOffsets=()=>[0,12,27,40];')};
 ctx.require=p=>requires[p];vm.runInNewContext(compile(imports+word),ctx);
 return {component:ctx.module.exports.MonetWordSweep,ctx};
}
const flatten=n=>[n,...n.children.filter(x=>x&&typeof x==='object').flatMap(flatten)];
const fields=n=>Object.fromEntries(['color','textShadow','maskImage','webkitMaskImage','backgroundImage'].filter(k=>n.style[k]!==undefined).map(k=>[k,n.style[k]?.get?n.style[k].get():n.style[k]]));
(async()=>{
 const old=await load(baseline);const next=await load(folder+'/MonetRailTokens.tsx');let comparisons=0;
 for(const lineStatus of ['active','passed','waiting'])for(const isChorus of [false,true]){
  let time=0,paint; const props={text:'abc',startTime:1,endTime:2,lineRenderEndTime:4,currentTime:{get:()=>time},registerWord:p=>{paint=p;p(time);return()=>{};},lineStatus,wordColor:'#aabbcc',baseColor:'rgba(32, 64, 96, 0.34)',fontPx:32,fontSpec:'700 32px monospace',fontsEpoch:0,isChorus,graphemeTimings:[{startTime:1,endTime:1.25},{startTime:1.25,endTime:1.75},{startTime:1.75,endTime:2}]};
  const node=next.component(props);for(const effect of next.ctx.effects.splice(0))effect();
  for(time of [-1,0,1,1.000001,1.4,2,2.1,3,4,6,20,2,1,0]){
   paint(time);const expected=flatten(old.component(props)),actual=flatten(node);
   for(let i=1;i<expected.length;i++){
    const e=fields(expected[i]),a=fields(actual[i]);
    if(e.maskImage!==undefined){a.maskImage??=a.webkitMaskImage;delete e.webkitMaskImage;delete a.webkitMaskImage;delete e.WebkitMaskImage;}
    assert.deepEqual(JSON.parse(JSON.stringify(a)),JSON.parse(JSON.stringify(e)),`${lineStatus}/${isChorus}/${time}/${i}`);
   } comparisons++;
  }
 }
 const record={wordPaintMatchesMobile16:true,temporalComparisons:comparisons,includesBackwardSeeks:true,measuredGlyphOffsetsStubbed:true};console.log(record);
})().catch(e=>{console.error(e);process.exitCode=1});

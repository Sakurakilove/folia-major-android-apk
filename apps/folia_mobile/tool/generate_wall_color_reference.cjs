const fs=require('node:fs'),path=require('node:path'),{chromium}=require('playwright');
const {baseline,sourceText}=require('./original_source.cjs');

// One isolated original CSS rule, not a full app/UI suite: legacy light and modern color-mix dark do not interpolate in the same color space.
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage({viewport:{width:100,height:100}}),cases=[];
  for(const daylight of [false,true]){
   const background=daylight?'#fafaf9':'#070707',ink=daylight?'#1c1917':'#f7f4ee';
   await page.setContent('<style>'+sourceText('src/library/suites/bravais/bravaisTileKinds.css')+'</style><div class="bravais-root'+(daylight?' is-daylight':'')+'" style="--text-accent:#fd5c47;--text-primary:'+ink+';--bg-color:'+background+'"><span class="bravais-tile-duo" id="duo"></span></div>');
   const data=await page.evaluate(async()=>{
    const node=document.getElementById('duo');getComputedStyle(node,'::after').backgroundColor;
    await new Promise(requestAnimationFrame);
    node.style.setProperty('--bravais-duo-light','hsl(213 62% 66%)');getComputedStyle(node).backgroundColor;
    const animations=node.getAnimations({subtree:true});animations.forEach(a=>a.pause());
    const timing=animations.map(a=>({pseudo:a.effect.pseudoElement,timing:a.effect.getTiming(),frames:a.effect.getKeyframes()}));
    const samples=[0,100,200,300,400].map(time=>{animations.forEach(a=>a.currentTime=time);return {time,light:getComputedStyle(node).backgroundColor,dark:getComputedStyle(node,'::after').backgroundColor}});
    return {timing,samples};
   });cases.push({daylight,background,ink,...data});
  }
  fs.writeFileSync(path.join(__dirname,'../test/fixtures/wall_color_reference.json'),JSON.stringify({baseline,engine:await browser.version(),cases})+'\n');
  console.log('Exported original CSS sRGB/Oklab artist transitions in day/night palettes.');
 }finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});

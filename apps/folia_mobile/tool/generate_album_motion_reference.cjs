const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {chromium}=require('playwright');
const {baseline,sourceText}=require('./original_source.cjs');

// One isolated original CSS surface with controlled animation time. No application navigation, real-time waits or visual acceptance claim.
(async()=>{
    const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
    try {
        const sources=['src/library/suites/bravais/bravaisPoster.css','src/library/suites/bravais/bravaisAlbumPoster.css'],
            page=await browser.newPage({viewport:{width:520,height:844}}),css=sources.map(sourceText).join('\n'),cases=[];
        for(const variant of ['ordinary','pending','landed','reduced']){
            const flight=variant==='pending'||variant==='landed'?` data-flight="${variant}"`:'',
                markup=`<section id="root" class="bravais-poster bravais-album-poster">
                    <div class="bravais-poster-ground"><div class="bravais-album-paper"></div><div id="hatch" class="bravais-album-hatch"></div><div id="dots" class="bravais-album-dots"></div><div id="ghost" class="bravais-album-ghost">X</div></div>
                    <div class="bravais-poster-ui"><div id="top" class="bravais-poster-top">X</div><div class="bravais-album-stage"><figure id="cover" class="bravais-album-cover"${flight}><span id="tape" class="bravais-album-tape"></span></figure><div id="scrap" class="bravais-album-scrap">X</div></div>
                    <div class="bravais-album-title-block"><span id="kicker" class="bravais-album-kicker">X</span><h2 class="bravais-album-title"><span id="word0" class="bravais-album-word" style="--bravais-album-word-index:0">A</span><span id="word1" class="bravais-album-word" style="--bravais-album-word-index:1">B</span><span id="word2" class="bravais-album-word" style="--bravais-album-word-index:2">C</span><span id="word3" class="bravais-album-word" data-space style="--bravais-album-word-index:3"> </span></h2><div id="underline" class="bravais-album-underline"></div></div>
                    <div class="bravais-poster-bottom bravais-album-bottom">${[0,1,2,3].map(i=>`<div id="bottom${i}">X</div>`).join('')}</div></div></section>`;
            await page.setContent(`<style>${css}</style><style>html,body{margin:0;width:100%;height:100%}.bravais-album-title{font-size:64px}</style><div class="bravais-root" style="width:520px;height:844px">${markup}</div>`);
            await page.evaluate(reduced=>{document.documentElement.dataset.reduceMotion=reduced?'lattice':'';},variant==='reduced');
            const timings=await page.evaluate(()=>document.getAnimations().map(a=>({target:a.effect.target.id,name:a.animationName,timing:a.effect.getTiming(),frames:a.effect.getKeyframes()}))),states=[];
            for(const at of [0,100,120,180,240,320,420,456,520,600,680,700,820,880,925,1000,1030,1100,1200]){
                states.push(await page.evaluate(at=>{
                    const animations=document.getAnimations();animations.forEach(a=>{a.pause();a.currentTime=at;});
                    const ids=['root','hatch','dots','ghost','cover','tape','scrap','kicker','word0','word1','word2','word3','underline','top','bottom0','bottom1','bottom2','bottom3'];
                    return {at,parts:ids.map(id=>{
                        const node=document.getElementById(id),style=getComputedStyle(node),
                            translate=style.translate==='none'?[0,0]:style.translate.split(' ').map(parseFloat),
                            scale=style.scale==='none'?[1,1]:style.scale.split(' ').map(parseFloat);
                        return {id,opacity:+style.opacity,x:translate[0]??0,y:translate[1]??0,
                            rotate:style.rotate==='none'?0:parseFloat(style.rotate),
                            scaleX:scale[0],scaleY:scale[1]??scale[0],visible:style.visibility!=='hidden',em:parseFloat(style.fontSize)};
                    })};
                },at));
            }
            cases.push({variant,timings,states});
        }
        fs.writeFileSync(path.join(__dirname,'../test/fixtures/album_motion_reference.json'),JSON.stringify({baseline,engine:await browser.version(),
            scope:'Isolated original CSS computed individual properties at controlled times; legacy transforms, clip drawing, text shadows/fonts/full pages/device output remain pending.',
            sourceHashes:Object.fromEntries(sources.map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),cases},null,2)+'\n');
        console.log('Exported four isolated original album entrance variants.');
    } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});

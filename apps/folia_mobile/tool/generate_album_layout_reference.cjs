const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {chromium}=require('playwright');
const {baseline,sourceText,load}=require('./original_source.cjs');

// Controlled content boxes isolate the original flex/position/percentage layout from still-pending font metrics and visual effects. This is not a full page acceptance fixture.
(async()=>{
    const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
    try {
        const sources=['src/library/suites/bravais/bravaisPoster.css','src/library/suites/bravais/bravaisAlbumPoster.css','src/library/suites/bravais/bravaisPosterComposition.ts'],
            css=sources.slice(0,2).map(sourceText).join('\n'),composition=load(sources[2]).resolveAlbumComposition('album:source'),
            page=await browser.newPage(),cases=[];
        for(const input of [{width:520,height:844,top:36,title:200,bottom:[20,40]},
            {width:680,height:360,top:60,title:190,bottom:[30,40,20]},
            {width:121,height:123,top:0,title:0,bottom:[]},
            {width:520,height:1200,top:36,title:420,bottom:[20,20,60,30]},
            {width:400,height:600,top:36,title:100,bottom:[20]}]) {
            await page.setViewportSize({width:input.width,height:input.height});
            await page.setContent(`<style>${css}</style><style>html,body{margin:0;width:100%;height:100%}*,*::before,*::after{animation:none!important;transform:none!important;translate:none!important;rotate:none!important;scale:none!important}</style><section class="bravais-poster bravais-album-poster"><div class="bravais-poster-ui"><div class="bravais-poster-top"><div id="top" style="width:100%;height:${input.top}px"></div></div><div id="stage" class="bravais-album-stage"><figure id="cover" class="bravais-album-cover"><span id="tape" class="bravais-album-tape" style="left:${composition.tape.x}%"></span></figure><div id="scrap" class="bravais-album-scrap" style="width:20px;height:100px"></div></div><div class="bravais-album-title-block"><div id="title" style="height:${input.title}px"></div></div><div class="bravais-poster-bottom bravais-album-bottom">${input.bottom.map((h,i)=>`<div id="bottom${i}" style="height:${h}px"></div>`).join('')}</div></div></section>`);
            await page.addStyleTag({content:'.bravais-album-tape{transform:translateX(-50%)!important}'});
            const boxes=await page.evaluate(()=>Object.fromEntries([...document.querySelectorAll('[id]')].map(node=>{
                const r=node.getBoundingClientRect();return [node.id,{x:r.x,y:r.y,width:r.width,height:r.height}];
            })));
            cases.push({input,boxes});
        }
        fs.writeFileSync(path.join(__dirname,'../test/fixtures/album_layout_reference.json'),JSON.stringify({baseline,engine:await browser.version(),
            scope:'Fixed content boxes with animations/rotations disabled, retaining tape half-width translation, to isolate CSS layout; real fonts and complete device pages remain pending.',
            seed:'album:source',composition,sourceHashes:Object.fromEntries(sources.map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),cases},null,2)+'\n');
        console.log('Exported five original album flex/cover/tape layouts.');
    } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});

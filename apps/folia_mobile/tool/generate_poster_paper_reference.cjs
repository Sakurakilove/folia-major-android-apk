const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {chromium}=require('playwright');
const {baseline,sourceText}=require('./original_source.cjs');

// Isolate the actual seam's artist/album paper in one tiny viewport, including 40vh bleed. No fonts, full application or motion suite.
(async()=>{
    const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']}),
        temporary=fs.mkdtempSync(path.join(os.tmpdir(),'folia-poster-paper-'));
    try {
        const sources=['src/library/suites/bravais/bravais.css','src/library/suites/bravais/bravaisPoster.css','src/library/suites/bravais/bravaisAlbumPoster.css'],
            css=sources.map(sourceText).join('\n'),page=await browser.newPage({viewport:{width:120,height:80},deviceScaleFactor:1}),cases=[];
        const session=await browser.newBrowserCDPSession(),system=await session.send('SystemInfo.getInfo');
        for(const input of [{album:false},{album:false,custom:true},{album:true},{album:true,custom:true}]) {
            await page.setContent(`<style>${css}</style><style>html,body{margin:0;background:transparent}</style><div class="bravais-root" style="width:120px;height:80px"><div class="bravais-seam" data-bravais-seam="poster" style="width:120px;visibility:visible"><div class="bravais-seam-content">${input.album?'<div class="bravais-album-poster"></div>':''}</div></div></div>`);
            if(input.custom) await page.evaluate(()=>{
                const style=document.querySelector('.bravais-root').style;
                Object.entries({'--bravais-poster-ground':'rgb(39,98,164)','--bravais-poster-ground-deep':'rgb(10,33,66)','--bravais-poster-edge':'#18243a',
                    '--bravais-album-paper':'#e8f0f4','--bravais-album-block':'#1b3d67'}).forEach(([k,v])=>style.setProperty(k,v));
            });
            const file=path.join(temporary,'paper.png'),points=[[0,0],[30,10],[60,40],[95,20],[110,60],[119,79],[80,79]];
            await page.screenshot({path:file,omitBackground:true});
            const pixels=JSON.parse(execFileSync('python3',['-c','from PIL import Image;import json,sys;im=Image.open(sys.argv[1]).convert("RGBA");print(json.dumps([list(im.getpixel(tuple(p))) for p in json.loads(sys.argv[2])]))',file,JSON.stringify(points)],{encoding:'utf8'}));
            cases.push({input,samples:points.map(([x,y],i)=>({x,y,rgba:pixels[i]}))});
        }
        fs.writeFileSync(path.join(__dirname,'../test/fixtures/poster_paper_reference.json'),JSON.stringify({baseline,engine:await browser.version(),
            raster:{featureStatus:system.gpu.featureStatus,skiaBackendType:system.gpu.auxAttributes?.skiaBackendType??null},
            scope:'Isolated DPR1 seam-paper observations; complete ground decorations, grain, fonts, all DPR, animations and device acceptance remain pending.',
            width:120,viewportHeight:80,paperHeight:144,bleed:32,
            sourceHashes:Object.fromEntries(sources.map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),cases},null,2)+'\n');
        console.log('Exported four original poster seam-paper surfaces.');
    } finally {await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(error=>{console.error(error);process.exitCode=1});

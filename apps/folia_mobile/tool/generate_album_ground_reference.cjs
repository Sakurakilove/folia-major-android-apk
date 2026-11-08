const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {chromium}=require('playwright');
const {baseline,sourceText,load}=require('./original_source.cjs');

// One small original ground, including a real 40px player safe area. Below the opaque ground, grain must blend inside the isolated poster before compositing onto seam paper.
(async()=>{
    const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']}),
        temporary=fs.mkdtempSync(path.join(os.tmpdir(),'folia-album-ground-'));
    try {
        const sources=['src/library/suites/bravais/bravais.css','src/library/suites/bravais/bravaisPoster.css',
            'src/library/suites/bravais/bravaisAlbumPoster.css','src/library/suites/bravais/bravaisPosterComposition.ts'],
            css=sources.slice(0,3).map(sourceText).join('\n'),model=load(sources[3]),seed='album:source',
            composition=model.resolveAlbumComposition(seed),
            page=await browser.newPage({viewport:{width:120,height:120},deviceScaleFactor:1}),cases=[],
            session=await browser.newBrowserCDPSession(),system=await session.send('SystemInfo.getInfo'),diagnostics=[];
        for(const custom of [false,true]) {
            await page.setContent(`<style>${css}</style><style>html,body{margin:0;background:transparent}</style><div class="bravais-root" style="width:120px;height:120px"><div class="bravais-seam" data-bravais-seam="poster" style="width:120px;visibility:visible"><div class="bravais-seam-content" style="width:120px;margin-left:-60px"><div class="bravais-seam-body" style="padding-bottom:40px"><section class="bravais-poster bravais-album-poster"><div class="bravais-poster-ground"><div class="bravais-album-paper"></div><div class="bravais-album-hatch"></div><div class="bravais-album-dots"></div><div class="bravais-album-ghost" data-side="${composition.ghostSide}"></div><div class="bravais-poster-grain"></div></div></section></div></div></div></div>`);
            await page.evaluate(async({custom,composition})=>{
                const root=document.querySelector('.bravais-root'),poster=document.querySelector('.bravais-album-poster');
                poster.style.setProperty('--bravais-album-divider-left',`${composition.divider.left}cqh`);
                poster.style.setProperty('--bravais-album-divider-right',`${composition.divider.right}cqh`);
                if(custom) Object.entries({'--bravais-album-paper':'#e8f0f4','--bravais-album-ink':'#192431','--bravais-album-block':'#1b3d67'})
                    .forEach(([k,v])=>root.style.setProperty(k,v));
                const url=getComputedStyle(document.querySelector('.bravais-poster-grain')).backgroundImage.slice(5,-2),
                    image=new Image();image.src=url;await image.decode();
            },{custom,composition});
            for(const at of [0,310,620,1200]) {
                await page.evaluate(at=>document.getAnimations().forEach(a=>{a.pause();a.currentTime=at;}),at);
                const file=path.join(temporary,'ground.png'),points=[[0,0],[5,3],[60,20],[60,40],[95,45],[110,60],[119,79],[60,100],[30,119]];
                await page.screenshot({path:file,omitBackground:true});
                const pixels=JSON.parse(execFileSync('python3',['-c','from PIL import Image;import json,sys;im=Image.open(sys.argv[1]).convert("RGBA");print(json.dumps([list(im.getpixel(tuple(p))) for p in json.loads(sys.argv[2])]))',file,JSON.stringify(points)],{encoding:'utf8'}));
                cases.push({custom,at,samples:points.map(([x,y],i)=>({x,y,rgba:pixels[i]}))});
            }
            if(!custom) {
                await page.addStyleTag({content:'.bravais-album-paper,.bravais-album-hatch,.bravais-album-dots,.bravais-album-ghost{visibility:hidden}.bravais-poster-ground,.bravais-seam[data-bravais-seam="poster"]{background:none!important}.bravais-poster-grain{mix-blend-mode:normal}'});
                for(const opacity of [1,.22]) {
                    await page.locator('.bravais-poster-grain').evaluate((node,opacity)=>node.style.opacity=opacity,opacity);
                    const file=path.join(temporary,'grain.png'),points=[[0,0],[5,3],[60,20],[60,40],[95,45],[110,60],[119,79],[60,100],[30,119]];
                    await page.screenshot({path:file,omitBackground:true});
                    const pixels=JSON.parse(execFileSync('python3',['-c','from PIL import Image;import json,sys;im=Image.open(sys.argv[1]).convert("RGBA");print(json.dumps([list(im.getpixel(tuple(p))) for p in json.loads(sys.argv[2])]))',file,JSON.stringify(points)],{encoding:'utf8'}));
                    diagnostics.push({opacity,samples:points.map(([x,y],i)=>({x,y,rgba:pixels[i]}))});
                }
            }
        }
        fs.writeFileSync(path.join(__dirname,'../test/fixtures/album_ground_reference.json'),JSON.stringify({baseline,engine:await browser.version(),
            raster:{featureStatus:system.gpu.featureStatus,skiaBackendType:system.gpu.auxAttributes?.skiaBackendType??null},
            scope:'Small source ground samples, empty ghost to exclude font differences; complete real glyphs, all DPR, full pages and device acceptance remain pending.',
            width:120,viewportHeight:120,contentHeight:80,paperHeight:216,bleed:48,seed,composition,
            sourceHashes:Object.fromEntries(sources.map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),cases,diagnostics},null,2)+'\n');
        console.log('Exported eight controlled original album-ground observations.');
    } finally {await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(error=>{console.error(error);process.exitCode=1});

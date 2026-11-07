const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {chromium}=require('playwright');
const {baseline,load,sourceText}=require('./original_source.cjs');

// Isolated actual original SVG images: small pixel samples at two DPR values, no full-page/browser acceptance suite.
(async()=>{
    const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
    try {
        const page=await browser.newPage(),
            wallSource='src/components/wall/wall.css',posterSource='src/library/suites/bravais/bravaisPoster.css',
            paperSource='src/utils/libraryWallSeamStyle.ts',
            looks=load(paperSource).LIBRARY_WALL_SEAM_STYLE_LOOKS,
            url=text=>text.match(/(?:background-image: )?url\("(data:image\/svg\+xml,[^"]+)"\)/)[1],
            recipes=[
                {name:'wall',recipe:'wall',logical:180,uri:url(sourceText(wallSource))},
                {name:'poster',recipe:'poster',logical:160,uri:url(sourceText(posterSource))},
                {name:'paperBlack',recipe:'paper',logical:180,whiteInk:false,uri:url(looks.white.surface)},
                {name:'paperWhite',recipe:'paper',logical:180,whiteInk:true,uri:url(looks.black.surface)},
            ],cases=[];
        for(const recipe of recipes) for(const dpr of [1,2]) {
            const samples=await page.evaluate(async({uri,logical,dpr})=>{
                const image=new Image();image.src=uri;await image.decode();
                const canvas=document.createElement('canvas');canvas.width=canvas.height=logical*dpr;
                const context=canvas.getContext('2d');context.scale(dpr,dpr);context.drawImage(image,0,0,logical,logical);
                const pixels=context.getImageData(0,0,canvas.width,canvas.height).data;
                return [[0,0],[1,1],[12,17],[90,90],[logical-1,logical-1]].map(([x,y])=>({
                    x:x*dpr,y:y*dpr,rgba:Array.from(pixels.slice((y*dpr*canvas.width+x*dpr)*4,(y*dpr*canvas.width+x*dpr)*4+4)),
                }));
            },{uri:recipe.uri,logical:recipe.logical,dpr});
            const {uri,...metadata}=recipe;cases.push({...metadata,dpr,samples});
        }
        fs.writeFileSync(path.join(__dirname,'../test/fixtures/wall_noise_reference.json'),JSON.stringify({
            baseline,engine:await browser.version(),
            scope:'Actual SVG textures only. Concrete CSS background sizing, material composition, all DPR values and final device pixels remain pending.',
            sourceHashes:Object.fromEntries([wallSource,posterSource,paperSource].map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),cases,
        },null,2)+'\n');
        console.log('Exported four original SVG recipes at two DPR values (forty pixel observations).');
    } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});

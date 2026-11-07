const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {chromium}=require('playwright');
const {baseline,load,sourceText}=require('./original_source.cjs');

// Small isolated material surfaces only: no application navigation, fonts, animation disabling or whole-page UI suite.
(async()=>{
    const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox']}),
        temporary=fs.mkdtempSync(path.join(os.tmpdir(),'folia-seam-material-'));
    try {
        const session=await browser.newBrowserCDPSession(), system=await session.send('SystemInfo.getInfo'),
            raster={featureStatus:system.gpu.featureStatus,skiaBackendType:system.gpu.auxAttributes?.skiaBackendType??null};
        const source='src/utils/libraryWallSeamStyle.ts', model=load(source),
            cssSources=['src/components/wall/wall.css','src/library/suites/bravais/bravais.css','src/library/suites/bravais/bravaisSeamLooks.css'],
            page=await browser.newPage({viewport:{width:120,height:80},deviceScaleFactor:1}),
            css=cssSources.map(sourceText).join('\n'), cases=[];
        for(const input of [
            ...model.LIBRARY_WALL_SEAM_STYLES.map(style=>({style})),
            {style:'white',width:6}, {style:'paper',seeThrough:true},
            {style:'white',clear:true}, {style:'black',clear:true,backdropBlur:true},
        ]) {
            const width=input.width??120,height=80;
            await page.setViewportSize({width,height});
            await page.setContent('<style>'+css+'</style><style>html,body{margin:0;background:transparent}.probe{background:none!important}.probe::before,.probe::after{display:none!important}.bravais-seam{width:100%;visibility:visible}</style><div id="root" class="lattice-root bravais-root probe"><div class="bravais-seam"></div></div>');
            await page.evaluate(async({input,vars,look})=>{
                const root=document.querySelector('#root');
                for(const [key,value] of Object.entries({'--bg-color':'#070707','--text-primary':'#f7f4ee','--text-accent':'#fd5c47','--text-secondary':'#6a48ff',...vars})) root.style.setProperty(key,value);
                if(!input.clear) root.dataset.bravaisSeamStyle=input.style;
                if(input.clear) root.classList.add('has-clear-seam');
                if(input.seeThrough) root.classList.add('is-see-through');
                if(input.backdropBlur) root.classList.add('has-backdrop-blur');
                const match=look.surface.match(/url\("(data:image\/svg\+xml,[^"]+)"\)/);
                if(match) {const image=new Image();image.src=match[1];await image.decode();}
            },{input,vars:input.clear?{}:model.libraryWallSeamStyleVars(input.style)??{},look:model.LIBRARY_WALL_SEAM_STYLE_LOOKS[input.style]});
            const image=path.join(temporary,'material.png');
            await page.screenshot({path:image,omitBackground:true});
            const points=[[0,0],[Math.min(5,width-1),20],[Math.floor(width/2),4],[Math.floor(width/2)+1,5],[Math.floor(width*.2),20],[Math.floor(width/2),40],[width-1,79]],
                pixels=JSON.parse(execFileSync('python3',['-c','from PIL import Image;import json,sys;im=Image.open(sys.argv[1]).convert("RGBA");p=json.loads(sys.argv[2]);print(json.dumps([list(im.getpixel(tuple(v))) for v in p]))',image,JSON.stringify(points)],{encoding:'utf8'}));
            cases.push({input,width,height,samples:points.map(([x,y],i)=>({x,y,rgba:pixels[i]}))});
        }
        fs.writeFileSync(path.join(__dirname,'../test/fixtures/seam_material_reference.json'),JSON.stringify({baseline,engine:await browser.version(),raster,
            scope:'Isolated static material samples only; source typography/controls/full surfaces/all DPR/device acceptance remain pending.',
            sourceHashes:Object.fromEntries([source,...cssSources].map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),cases},null,2)+'\n');
        console.log('Exported twelve isolated original seam material cases.');
    } finally {await browser.close();fs.rmSync(temporary,{recursive:true,force:true});}
})().catch(error=>{console.error(error);process.exitCode=1});

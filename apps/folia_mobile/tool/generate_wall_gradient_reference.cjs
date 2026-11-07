const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { chromium } = require('playwright');
const { baseline, sourceText } = require('./original_source.cjs');

// Five single-pixel samples, including the original tint rule. This isolated color-space diagnostic is not a full UI/browser acceptance suite.
(async()=>{
    const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox']}),
        temp=fs.mkdtempSync(path.join(os.tmpdir(),'folia-gradient-'));
    try {
        const source='src/components/wall/wall.css',css=sourceText(source),
            page=await browser.newPage({viewport:{width:3,height:5},deviceScaleFactor:1});
        await page.setContent('<style>'+css+'</style><style>body{margin:0}body>div{width:3px;height:1px}#a{background:linear-gradient(90deg,red,blue)}#b{background:linear-gradient(90deg,color-mix(in srgb,red 100%,black),color-mix(in srgb,blue 100%,black))}#c{background:linear-gradient(90deg,red,transparent)}#d{background:linear-gradient(90deg,color-mix(in srgb,red 100%,black),transparent)}#original{position:relative;inset:auto;background:none;isolation:auto}#original::after{display:none}</style><div id="a"></div><div id="b"></div><div id="c"></div><div id="d"></div><div id="original" class="lattice-root has-poster-tint" style="--bg-color:#070707;--text-accent:#fd5c47;--text-secondary:#6a48ff;--lattice-poster-tint-intensity:1"><span class="lattice-poster-tint"></span></div>');
        const computed=await page.evaluate(()=>[a,b,c,d,document.querySelector('#original span')].map(n=>getComputedStyle(n).backgroundImage)),
            image=path.join(temp,'pixels.png');
        await page.screenshot({path:image,omitBackground:true});
        const pixels=JSON.parse(execFileSync('python3',['-c','from PIL import Image; import json,sys; im=Image.open(sys.argv[1]).convert("RGBA"); print(json.dumps([im.getpixel((1,y)) for y in range(5)]))',image],{encoding:'utf8'}));
        const styles=['src/library/suites/bravais/bravais.css','src/library/suites/bravais/bravaisTileKinds.css','src/library/suites/bravais/bravaisHome.css','src/library/suites/bravais/bravaisPoster.css'];
        await page.setContent('<style>'+css+styles.map(sourceText).join('\n')+'</style><div class="lattice-root bravais-root has-poster-wall" id="poster"></div>');
        const posterCases=await page.evaluate(()=>{
            const cases=[{},{dimmed:true},{unavailable:true},{selected:true},{focused:true},{current:true},
                {kind:'heading'},{kind:'wall'},{kind:'window'},{expanded:true},{linked:true}];
            return cases.map(flags=>{
                const tile=document.createElement('div'),face=document.createElement('article');
                tile.className='bravais-tile'+(flags.focused?' is-focused':'')+(flags.expanded?' is-expanded':'');
                tile.dataset.bravaisKind=flags.kind??'track';if(flags.current) tile.dataset.bravaisCurrent='';
                face.className='lattice-poster bravais-tile-face'+(flags.kind?' is-'+flags.kind:'')+
                    Object.keys(flags).filter(k=>k!=='kind').map(k=>' is-'+k).join('');
                tile.appendChild(face);poster.replaceChildren(tile);
                const style=getComputedStyle(face);
                return {flags,filter:style.filter,inset:parseFloat(style.left),tint:Number(getComputedStyle(tile,'::after').opacity)};
            });
        });
        const seamStyles=['src/library/suites/bravais/bravais.css','src/library/suites/bravais/bravaisAppearance.css'];
        await page.setContent('<style>'+css+seamStyles.map(sourceText).join('\n')+'</style><div id="root"></div>');
        const seamCases=await page.evaluate(()=>{
            const cases=[{}, {tintIntensity:1}, {daylight:true}, {tinted:false}, {lightsOut:true},
                {lightsOut:true,wallClear:true}, {lightsOut:true,clearSeam:true}, {clearSeam:true},
                {wallClear:true}, {menuOpen:true}, {keyboardWindow:true}, {variant:'form'},
                {variant:'search'}, {variant:'poster'}];
            return cases.map(flags=>{
                root.className='lattice-root bravais-root'+(flags.daylight?' is-daylight':'')+
                    (flags.tinted===false?'':' has-poster-tint')+(flags.lightsOut?' is-lights-out':'')+
                    (flags.clearSeam?' has-clear-seam':'');
                root.dataset.bravaisLook=flags.wallClear?'clear':'solid';
                root.style.setProperty('--lattice-poster-tint-intensity',String(flags.tintIntensity??.5));
                const seam=document.createElement('div'),body=document.createElement('div');
                seam.className='bravais-seam';seam.dataset.bravaisSeam=flags.variant??'full';
                if(flags.keyboardWindow) seam.dataset.foliaKeyboardWindow='';
                body.className='bravais-seam-body';seam.append(body);
                if(flags.menuOpen) body.innerHTML='<span data-bravais-seam-menu></span>';
                root.replaceChildren(seam);
                return {flags,paperTint:Number(getComputedStyle(seam,'::before').opacity),
                    textTint:Number(getComputedStyle(seam,'::after').opacity),bodyOpacity:Number(getComputedStyle(body).opacity)};
            });
        });
        fs.writeFileSync(path.join(__dirname,'../test/fixtures/wall_gradient_reference.json'),JSON.stringify({baseline,engine:await browser.version(),source,sourceHash:crypto.createHash('sha256').update(css).digest('hex'),computed,pixels,posterCases,seamCases,
            styleHashes:Object.fromEntries([...new Set([...styles,...seamStyles])].map(s=>[s,crypto.createHash('sha256').update(sourceText(s)).digest('hex')]))},null,2)+'\n');
        console.log('Exported five isolated original CSS gradient/alpha center pixels.');
    } finally { await browser.close();fs.rmSync(temp,{recursive:true,force:true}); }
})().catch(error=>{console.error(error);process.exitCode=1;});

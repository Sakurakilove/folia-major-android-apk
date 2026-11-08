const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {chromium}=require('playwright');
const {baseline,sourceText}=require('./original_source.cjs');

// One small source control, forced pseudo-states and computed styles only. No fonts, mixed-backdrop pixels, full app, or device acceptance.
(async()=>{
    const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
    try {
        const sources=['src/library/suites/bravais/bravaisPoster.css','src/library/suites/bravais/bravaisAlbumPoster.css'],css=sources.map(sourceText).join('\n'),cases=[];
        for(const dpr of [1,2,3.5]) {
            const page=await browser.newPage({deviceScaleFactor:dpr}),session=await page.context().newCDPSession(page);
            await session.send('DOM.enable');await session.send('CSS.enable');
            for(const album of [false,true]) for(const primary of [false,true]) for(const hovered of [false,true]) {
                if(dpr!==1&&(album||primary||hovered)) continue;
                await page.setContent(`<style>${css}</style><div class="bravais-root"><section class="bravais-poster${album?' bravais-album-poster':''}"><button id="button" class="bravais-poster-button${primary?' is-primary':''}">Play</button></section></div>`);
                const {root}=await session.send('DOM.getDocument'),{nodeId}=await session.send('DOM.querySelector',{nodeId:root.nodeId,selector:'#button'});
                await session.send('CSS.forcePseudoState',{nodeId,forcedPseudoClasses:hovered?['hover']:[]});
                const style=await page.locator('#button').evaluate(node=>{
                    const s=getComputedStyle(node),color=text=>{
                        const values=(text.match(/[+-]?(?:\d*\.)?\d+(?:e[+-]?\d+)?/gi)||[]).map(Number);
                        return text.startsWith('color(')?[...values.slice(0,3),values[3]??1]:[...values.slice(0,3).map(n=>n/255),values[3]??1];
                    };
                    return {background:color(s.backgroundColor),border:color(s.borderTopColor),ink:color(s.color),borderWidth:parseFloat(s.borderTopWidth),weight:+s.fontWeight,
                        shadow:s.boxShadow==='none'?null:color(s.boxShadow.match(/(?:color|rgba?|color-mix)\([^)]*\)/)[0]),height:node.getBoundingClientRect().height};
                });
                cases.push({input:{album,primary,hovered,dpr},style});
            }
            await page.close();
        }
        fs.writeFileSync(path.join(__dirname,'../test/fixtures/poster_control_reference.json'),JSON.stringify({baseline,engine:await browser.version(),
            scope:'Original computed-style targets and no-transform minimum height; real glyphs, backdrop compositing, focus pixels/full pages/devices remain pending.',
            sourceHashes:Object.fromEntries(sources.map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),cases},null,2)+'\n');
        console.log('Exported ten original poster control styles.');
    } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});

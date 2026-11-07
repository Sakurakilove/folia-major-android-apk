const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {baseline,load,sourceText}=require('./original_source.cjs');

// A pure source oracle for seed geometry and discrete palette rules. It does not measure fonts, images or whole poster pixels.
const sources=['src/library/suites/bravais/bravaisPosterComposition.ts','src/library/suites/bravais/bravaisPosterPalette.ts',
    'src/components/visualizer/tempera/temperaPalette.ts','src/components/visualizer/colorMix.ts'],
    composition=load(sources[0]),poster=load(sources[1]),tempera=load(sources[2]),color=load(sources[3]),
    seeds=['','artist:123','album:123','歌手:星野源','网易云:😀','\u0000\uffff',...Array.from({length:16},(_,i)=>`artist:${i}`)],
    geometry=seeds.map(seed=>{const p=composition.resolvePosterComposition(seed),random=composition.createRandom(composition.hashPosterSeed(seed));
        return {seed,hash:composition.hashPosterSeed(seed),random:Array.from({length:5},random),artist:p,
            album:composition.resolveAlbumComposition(seed),clip:composition.posterShapeClipPath(p.shape),
            risen:p.shape.kind==='polygon'?composition.risePosterPoints(p.shape.points):null};}),
    themes=[
        {backgroundColor:'#070707',primaryColor:'#f7f4ee',accentColor:'#fd5c47',secondaryColor:'#6a48ff'},
        {backgroundColor:'#fff',primaryColor:'#eee',accentColor:'#ffb900',secondaryColor:'#056aaa'},
        {backgroundColor:'#777777',primaryColor:'#888888',accentColor:'#999999',secondaryColor:'#444444'},
        {backgroundColor:'hsl(10, 20%, 30%)',primaryColor:'invalid',accentColor:'rgba(300, -20, 5, .2)',secondaryColor:'#abc'},
    ].map(theme=>({name:'source',fontStyle:'sans',animationIntensity:'normal',...theme})),
    covers=[[],['#f00'],['#fd5c47','#6a48ff'],['#070707','#f7f4ee','#777777'],
        ['#ff0000','#00ff00','#0000ff','#ffff00','#00ffff'],['#333','#333','#333'],
        ['rgba(33, 120, 244, .2)','#ee1122','hsl(20, 50%, 50%)']],
    palettes=themes.flatMap(theme=>covers.flatMap(coverColors=>['mono','duo','gradient'].map(colorMode=>({theme,coverColors,colorMode,
        expected:tempera.resolveTemperaPalette(theme,{colorMode},coverColors)})))),
    posterPalettes=covers.map(colors=>({colors,artist:poster.resolveBravaisPosterPalette(colors),album:poster.resolveBravaisAlbumPalette(colors)})),
    colors=['','#abc','#112233',' #aBcDef ','#1234','red','hsl(10, 20%, 30%)','rgb(10.5, 20.5, 30.5)',
        'rgba(0x10, 50%, -5, .2)','rgb(10 20 30)','RGB(1, 2, 3)','rgba(300, -20, 5, 0.2)','\u0085#abc','\ufeff#abc'],
    colorCases=colors.map((input,i)=>({input,channels:color.parseColorChannels(input),alpha:color.colorWithAlpha(input,.35),
        mixes:[-.1,0,.49999999999999994,.5,1,1.1].map(amount=>({to:colors[(i+3)%colors.length],amount,
            expected:color.mixColors(input,colors[(i+3)%colors.length],amount,.7)}))}));
fs.writeFileSync(path.join(__dirname,'../test/fixtures/poster_reference.json'),JSON.stringify({baseline,
    scope:'Pure original function outputs only; complete scene/font/animation/device acceptance remains pending.',
    sourceHashes:Object.fromEntries(sources.map(p=>[p,crypto.createHash('sha256').update(sourceText(p)).digest('hex')])),
    geometry,palettes,posterPalettes,colorCases,
    interleaved:poster.interleavePosterColors([['a','b'],[],['c'],['d','e','f']]),
},null,2)+'\n');
console.log(`Exported ${geometry.length} original compositions, ${palettes.length} palettes and ${colorCases.length} color cases.`);

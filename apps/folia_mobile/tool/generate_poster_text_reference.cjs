const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const Module=require('node:module');
const crypto=require('node:crypto');
const {baseline,sourceText}=require('./original_source.cjs');

// Evaluate the actual source helper bodies, without mounting React or substituting handwritten reference formulas. Native ICU version/device segmentation is still a separate comparison.
const files=['src/library/suites/bravais/BravaisSeamPoster.tsx','src/library/suites/bravais/BravaisSeamAlbumPoster.tsx'],
    [artist,album]=files.map(sourceText),
    bodies=artist.slice(artist.indexOf('const nameColumns ='),artist.indexOf('const PosterSong:'))
        +artist.slice(artist.indexOf('export const scrapWords ='),artist.indexOf('const BravaisSeamPoster:'))
        +album.slice(album.indexOf('const WIDE ='),album.indexOf('/** 入场')),
    ghost=album.slice(album.indexOf('const hero = words.find'),album.indexOf('const composition = useMemo')),
    code=Module.stripTypeScriptTypes(bodies.replace(/^export /gm,''),{mode:'transform'}),
    api=vm.runInNewContext(`${code};({nameColumns,titleColumns,splitHeroWord,scrapWords,ghost:(title,words)=>{${ghost};return ghost;}})`,{Intl,BRAVAIS_POSTER_SCRAP_COUNT:2}),
    titles=['','Ignition','Hello Beautiful World','hello hello','你好 世界','イグニッション','안녕하세요 세계','火🔥と 水','e\u0301 égalité café','👩‍👩‍👧‍👦 day night','𠀀 𠀁 hello','𑼄 long word','\ufeff  Alpha\u00a0Beta \ufeff','\u0085Alpha Beta','İSTANBUL ΣΟΣ ΟΣ','123 4567 89','a-b-c def','Rock ’n’ Roll','love LOVE Love','\u3000\u3000','\ud800test end'],
    segmenter=new Intl.Segmenter(undefined,{granularity:'word'}),
    cases=titles.map(title=>{const words=api.splitHeroWord(title);return {title,parts:[...segmenter.segment(title)].map(p=>({text:p.segment,index:p.index,wordLike:!!p.isWordLike})),words,
        ghost:api.ghost(title,words),nameColumns:api.nameColumns(title),albumColumns:api.titleColumns(title)};}),
    groups=[['Hello Beautiful World','World Beautiful Hello','Beautiful Hello'],['love LOVE Love','LOVE forever','love forever'],['İSTANBUL ΣΟΣ','istanbul ΟΣ','ΣΟΣ ΟΣ'],[' ignition ','ignition','👩‍👩‍👧‍👦'],['你好 世界','世界 你好','你好世界'],['','','a'],['𠀀 𠀁 hello','hello 𠀀','𠀀𠀁']].map(titles=>({titles,expected:api.scrapWords(titles.map(title=>({title})))})),
    preparedTitles=[...new Set([...titles,...groups.flatMap(g=>g.titles)].flatMap(s=>[s,s.trim()]))],
    prepared=preparedTitles.map(title=>({title,parts:[...segmenter.segment(title)].map(p=>({text:p.segment,index:p.index,wordLike:!!p.isWordLike}))})),
    candidates=[...new Set(preparedTitles.flatMap(title=>[...[...segmenter.segment(title.trim())].filter(p=>p.isWordLike).map(p=>p.segment),[...title.trim()].slice(0,2).join('')]))];
fs.writeFileSync(path.join(__dirname,'../test/fixtures/poster_text_reference.json'),JSON.stringify({baseline,node:process.version,icu:process.versions.icu,unicode:process.versions.unicode,
    locale:segmenter.resolvedOptions().locale,scope:'Original helper/Intl observations only; device ICU version, glyphs and complete poster acceptance remain pending.',
    sourceHashes:Object.fromEntries(files.map((p,i)=>[p,crypto.createHash('sha256').update([artist,album][i]).digest('hex')])),cases,groups,prepared,
    lowercase:Object.fromEntries(candidates.map(s=>[s,s.toLocaleLowerCase()]))},null,2)+'\n');
console.log(`Exported ${cases.length} source title and ${groups.length} scrap observations.`);

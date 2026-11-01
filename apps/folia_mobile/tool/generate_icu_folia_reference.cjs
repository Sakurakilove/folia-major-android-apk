const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
const {baseline,sourceText,load}=require('./original_source.cjs');

// Execute the baseline engine factory with its dynamic data imports supplied by the exported original tables; no replacement engine is its own oracle.
async function main() {
    const read=name=>JSON.parse(fs.readFileSync(path.join(__dirname,`../assets/icu_folia/${name}.json`),'utf8'));
    const dictionary=read('dictionary'),hmm=read('hmm');
    const data={words:dictionary.words,freqs:dictionary.freqs,total:dictionary.total,hmm:{start:hmm.start,trans:hmm.trans,emit:hmm.emit}};
    const {createJieba}=load('src/utils/lyrics/icuFolia/jieba.ts');
    const lexicon=load('src/utils/lyrics/icuFolia/jiebaLexicon.ts');
    const {Parser,jaModel}=require('budoux');
    let source=sourceText('src/utils/lyrics/icuFolia/engines.ts').replace(/^import .*;\n/gm,'').replace('export const loadIcuFoliaEngines','const loadIcuFoliaEngines');
    for (const [name,value] of [["import('virtual:icu-folia-dict')",'Promise.resolve(sourceDictionary)'],
        ["import('virtual:icu-folia-hmm')",'Promise.resolve(sourceHmm)'],["import('./budouxJapanese')",'Promise.resolve({createJapaneseParser:sourceJapanese})']]) {
        if(!source.includes(name)) throw Error(`Original engine import changed: ${name}`);source=source.replace(name,value);
    }
    const sandbox={createJieba,...lexicon,sourceDictionary:{DICT_WORDS:dictionary.words,DICT_FREQS:dictionary.freqs,DICT_TOTAL:dictionary.total},
        sourceHmm:{HMM_START:hmm.start,HMM_TRANS:hmm.trans,HMM_EMIT:hmm.emit,T2S_PAIRS:hmm.t2s},sourceJapanese:()=>new Parser(jaModel)};
    vm.runInNewContext(stripTypeScriptTypes(source+'\nglobalThis.factory=loadIcuFoliaEngines;',{mode:'transform'}),sandbox);
    const engines=await sandbox.factory(),segment=load('src/utils/lyrics/icuFolia/segmenter.ts').segmentWithIcuFolia;
    const corpus=load('test/unit/lyrics/icuFolia/corpus.ts');
    const texts=[...new Set([...Object.values(corpus.GOLDEN).flatMap(rows=>rows.slice(0,2).map(c=>c.text)),
        ...Object.values(corpus.KNOWN_GAPS).flat().map(c=>c.text),'','𠮷野家的饭','ABC中文123','葛󠄀城','rock‐and‑roll 君の夢'])];
    const plain=new Intl.Segmenter(undefined,{granularity:'word'});
    const cases=texts.map(text=>({text,plain:Array.from(plain.segment(text),p=>p.segment),expected:segment(text,engines),
        withoutEngines:segment(text,null),chinese:engines.cutChinese(text),japanese:engines.parseJapanese(text)}));
    const stock=JSON.parse(sourceText('test/unit/lyrics/icuFolia/jiebaReference.json')).stock.slice(0,24);
    const raw=createJieba(data),updates=[];
    for (const [word,frequency] of [...lexicon.CHINESE_EXTRA_WORDS.map(w=>[w,undefined]),...lexicon.CHINESE_DEMOTED_WORDS.map(w=>[w,1])]) {
        updates.push({word,...(frequency===undefined?{}:{frequency}),expected:raw.addWord(word,frequency)});
    }
    fs.writeFileSync(path.join(__dirname,'../test/fixtures/icu_folia_reference.json'),JSON.stringify({baseline,
        scope:'Source Chinese/Japanese/pipeline rules with source-supplied ICU pieces; not device ICU, worker scheduling, glyph or frontend acceptance.',cases,stock,updates},null,2)+'\n');
    console.log(`${cases.length} original mixed-language pipeline cases and ${stock.length} existing jieba reference lines exported.`);
}
main().catch(error=>{console.error(error);process.exitCode=1;});

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const vm = require('node:vm');
const {pathToFileURL} = require('node:url');
const {execFileSync} = require('node:child_process');
const {root,baseline,sourceText,load} = require('./original_source.cjs');

// Run the unchanged baseline data plugin; only dictionaries/models/numeric log tables enter Android, never the JavaScript engine or app code.
async function main() {
    const out = path.join(__dirname,'../assets/icu_folia');
    fs.mkdirSync(out,{recursive:true});
    const hashes = {};
    const sha = data=>crypto.createHash('sha256').update(data).digest('hex');
    function track(relative) {
        const local=fs.readFileSync(path.join(root,relative));
        const original=execFileSync('git',['show',`${baseline}:${relative}`],{cwd:root,maxBuffer:24*1024*1024});
        if (!local.equals(original)) throw Error(`Baseline data changed: ${relative}`);
        hashes[relative]=sha(original);
    }
    const pluginPath='dev/icuFolia/icuFoliaDataPlugin.mjs';
    track(pluginPath);
    for (const name of ['jieba','segmenter','lexicon','jiebaLexicon','engines','budouxJapanese']) track(`src/utils/lyrics/icuFolia/${name}.ts`);
    const {icuFoliaDataPlugin,DICT_MODULE_ID,HMM_MODULE_ID}=await import(pathToFileURL(path.join(root,pluginPath)));
    const plugin=icuFoliaDataPlugin();
    function readModule(id,names) {
        const code=plugin.load.call({addWatchFile:file=>track(path.relative(root,file))},`\0${id}`);
        const sandbox={};
        vm.runInNewContext(code.replace(/^export const /gm,'const ')+`\nglobalThis.result={${names.join(',')}};`,sandbox);
        return sandbox.result;
    }
    const dict=readModule(DICT_MODULE_ID,['DICT_WORDS','DICT_FREQS','DICT_TOTAL']);
    const hmm=readModule(HMM_MODULE_ID,['HMM_START','HMM_TRANS','HMM_EMIT','T2S_PAIRS']);
    const words=dict.DICT_WORDS.split('\n'),bytes=Buffer.from(dict.DICT_FREQS,'base64');
    const freqs=new Uint32Array(words.length);
    for (let i=0,cursor=0;i<freqs.length;i++) {
        let value=0,scale=1,byte;
        do { byte=bytes[cursor++];value+=(byte&127)*scale;scale*=128; } while (byte>=128);
        freqs[i]=value;
    }
    const unique=[...new Set([1,...freqs].filter(n=>n>0))].sort((a,b)=>a-b);
    const dictionary={words:dict.DICT_WORDS,freqs:dict.DICT_FREQS,total:dict.DICT_TOTAL,logTotal:Math.log(dict.DICT_TOTAL),
        logFrequencies:unique.map(freq=>[freq,Math.log(freq)])};
    const data={words:dict.DICT_WORDS,freqs:dict.DICT_FREQS,total:dict.DICT_TOTAL,
        hmm:{start:hmm.HMM_START,trans:hmm.HMM_TRANS,emit:hmm.HMM_EMIT}};
    const jieba=load('src/utils/lyrics/icuFolia/jieba.ts').createJieba(data,{maxHmmWordLength:2});
    const lexical=load('src/utils/lyrics/icuFolia/jiebaLexicon.ts'),particles=load('src/utils/lyrics/icuFolia/lexicon.ts');
    const added=new Map();
    function oldFrequency(word) {
        if (added.has(word)) return added.get(word);
        let low=0,high=words.length;
        while (low<high) { const mid=(low+high)>>>1;if(words[mid]<word) low=mid+1;else high=mid; }
        return low<words.length&&words[low]===word?freqs[low]:0;
    }
    let total=dict.DICT_TOTAL;
    const updates=[...lexical.CHINESE_EXTRA_WORDS.map(word=>[word,undefined]),...lexical.CHINESE_DEMOTED_WORDS.map(word=>[word,1])].map(([word,freq])=>{
        const old=oldFrequency(word),weight=jieba.addWord(word,freq);total+=weight-old;added.set(word,weight);
        return {word,frequency:weight,total,logTotal:Math.log(total),logFrequency:Math.log(weight)};
    });
    function packageRoot(name) {
        let dir=path.dirname(require.resolve(name));
        while (!fs.existsSync(path.join(dir,'package.json'))||JSON.parse(fs.readFileSync(path.join(dir,'package.json'))).name!==name) {
            const parent=path.dirname(dir);if(parent===dir) throw Error(`Package root missing: ${name}`);dir=parent;
        }
        return dir;
    }
    const locked=JSON.parse(sourceText('package-lock.json')).packages,versions={};
    for (const name of ['budoux','opencc-js']) {
        versions[name]=JSON.parse(fs.readFileSync(path.join(packageRoot(name),'package.json'),'utf8')).version;
        if (versions[name]!==locked[`node_modules/${name}`].version) throw Error(`${name} differs from baseline`);
    }
    const {jaModel}=require('budoux');
    const outputs={};
    function write(name,value) {
        const bytes=typeof value==='string'?Buffer.from(value):Buffer.from(JSON.stringify(value)+'\n');
        fs.writeFileSync(path.join(out,name),bytes);outputs[name]={sha256:sha(bytes),bytes:bytes.length};
    }
    write('dictionary.json',dictionary);
    write('hmm.json',{start:hmm.HMM_START,trans:hmm.HMM_TRANS,emit:hmm.HMM_EMIT,t2s:hmm.T2S_PAIRS});
    write('japanese.json',jaModel);
    write('lexicon.json',{updates,trailingParticles:[...particles.CHINESE_TRAILING_PARTICLES],nonHosts:[...particles.CHINESE_NON_HOSTS],maxHmmWordLength:2});
    track('dev/icuFolia/jieba/LICENSE');
    write('jieba-LICENSE.txt',sourceText('dev/icuFolia/jieba/LICENSE'));
    write('Apache-2.0.txt',fs.readFileSync(path.join(packageRoot('opencc-js'),'LICENSES/Apache-2.0.txt'),'utf8'));
    write('opencc-LICENSE.txt',fs.readFileSync(path.join(packageRoot('opencc-js'),'LICENSE'),'utf8'));
    write('opencc-THIRD-PARTY-LICENSES.txt',fs.readFileSync(path.join(packageRoot('opencc-js'),'THIRD_PARTY_LICENSES.md'),'utf8'));
    write('NOTICE.txt','BudouX Japanese model and parser: Copyright 2021 Google LLC, Apache-2.0.\nJieba dictionary/HMM and Folia reimplementation: see jieba-LICENSE.txt and original application LICENSE.\nTraditional/simplified character pairs derive from the baseline OpenCC data; see bundled OpenCC licenses.\nGenerated numeric log tables preserve baseline JavaScript math at the build boundary.\n');
    write('provenance.json',{baseline,generator:'apps/folia_mobile/tool/export_icu_folia_assets.cjs',formatVersion:1,
        versions,inputs:hashes,outputs,wordCount:words.length,logFrequencyCount:unique.length,hmmFloatEndianness:'little',
        scope:'Original data and default lexicon; Android ICU, document worker and final segmentation/visual parity require their own verification.'});
    console.log(`${words.length} original dictionary words, ${unique.length} exact log values and Japanese/HMM data exported.`);
}
main().catch(error=>{console.error(error);process.exitCode=1;});

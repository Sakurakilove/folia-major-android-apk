const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {stripTypeScriptTypes} = require('node:module');
const {baseline,load,sourceText} = require('./original_source.cjs');

// Execute original layout and original per-word map body. Plain word boundaries come from the original engine, not a claimed native ICU port.
const model = load('src/components/visualizer/partita/partitaLayout.ts');
const segmenter = load('src/utils/lyrics/wordSegmentation.ts');
const defaults = load('src/types.ts').DEFAULT_PARTITA_TUNING;
const chunk = sourceText('src/components/visualizer/partita/PartitaChunk.tsx');
const wordBody = chunk.slice(chunk.indexOf('                const wordSeed'),chunk.indexOf('                return (',chunk.indexOf('                const wordSeed')));
const visualizer = sourceText('src/components/visualizer/partita/VisualizerPartita.tsx');
const fontBody = visualizer.slice(visualizer.indexOf('    const densityScale'),visualizer.indexOf('    const layoutVariants'));
const cases = [];
const lines = JSON.parse(fs.readFileSync(path.join(__dirname,'../test/fixtures/lyric_reference.json'),'utf8')).semanticCases.map(c=>c.line);
for (const line of [...lines,{fullText:'',startTime:0,endTime:1,words:[]}]) for (const intensity of ['calm','normal','chaotic'])
    for (const height of [280,800]) for (const semantic of [false,true]) {
        const tuning=model.resolvePartitaTuning({...defaults,useSemanticLayout:semantic,staggerMin:90,staggerMax:15});
        const theme={animationIntensity:intensity,fontWeight:619};
        const layout=model.getOrBuildPartitaLayout(new Map(),line,theme,height,tuning);
        const wordConfigs=layout.columns.map(column=>column.words.map(chunk=>chunk.displayWords.map((w,idx)=>{
            const sandbox={displayWords:chunk.displayWords,config:chunk.config,idx,theme};
            vm.runInNewContext(stripTypeScriptTypes('globalThis.result=(()=>{'+wordBody+'return wordConfig;})();',{mode:'transform'}),sandbox);
            return sandbox.result;
        })));
        const fonts={sequentialLayout:layout,lyricsFontScale:1.23456};
        vm.runInNewContext(fontBody+'globalThis.result={main:mainFontSize,empty:emptyFontSize,translation:translationFontSize,upcoming:upcomingFontSize};',fonts);
        cases.push({line,plain:segmenter.segmentTextWords(line.fullText),intensity,height,tuning,
            key:model.buildPartitaLayoutCacheKey(line,theme,height,tuning),layout,wordConfigs,fontScale:fonts.lyricsFontScale,fonts:fonts.result});
    }
fs.writeFileSync(path.join(__dirname,'../test/fixtures/partita_reference.json'),JSON.stringify({baseline,
    scope:'Source layouts/word parameters/font strings only; supplied original plain boundaries, no native ICU, fonts, frame or pixel acceptance.',cases},null,2)+'\n');
console.log(`${cases.length} original Partita chunk/word layouts generated.`);

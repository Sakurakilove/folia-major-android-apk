const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const { root, load } = require('./original_source.cjs');

// Execute the baseline TS functions as the oracle; deterministic measurement isolates geometry from font engines.
const originalLoad = Module._load;
const textWidth = text => [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(text)].length * 11;
const pretext = {
    clearCache() {},
    prepareWithSegments: (text, font) => ({ text, font }),
    layoutWithLines: (prepared, width) => ({ lines: Array.from({ length: Math.max(1, Math.ceil(textWidth(prepared.text) / width)) }, () => ({ width: Math.min(width, textWidth(prepared.text)) })) }),
};
const rich = {
    prepareRichInline: (items) => items,
    measureRichInlineStats(items, width) {
        let count = 1, x = 0, widest = 0;
        for (const item of items) {
            const advance = textWidth(item.text);
            if (x && x + advance > width) { widest = Math.max(widest, x); count++; x = 0; }
            x += advance;
        }
        return { lineCount: count, maxLineWidth: Math.max(widest, x) };
    },
};
Module._load = function (request, parent, main) {
    if (request === '@chenglou/pretext') return pretext;
    if (request === '@chenglou/pretext/rich-inline') return rich;
    return originalLoad.call(this, request, parent, main);
};
const timing = load('src/utils/lyrics/graphemeTiming.ts');
const hints = load('src/utils/lyrics/renderHints.ts');
const subtitles = load('src/utils/lyrics/alternateText.ts');
const model = load('src/components/visualizer/monet/monetLyricsModel.ts');
const rail = load('src/components/visualizer/monet/monetRailLayout.ts');
const motion = load('src/components/visualizer/monet/monetLyricMotion.ts');
const fonts = load('src/utils/fontStacks.ts');
const colors = load('src/components/visualizer/wordColoring.ts');
const portraits = load('src/components/visualizer/monet/monetPortraitCrossfade.ts');
const line = (fullText, startTime, endTime, words = [], extra = {}) => ({ fullText, startTime, endTime, words, ...extra });
const word = (text, startTime, endTime, extra = {}) => ({ text, startTime, endTime, ...extra });
const lines = [
    line('///', 0, .05),
    line('你好，你好！', .5, 3, [word('你好', .5, 1), word('你好', 1.7, 2.8)], {
        translation: ' hello ', romanization: 'ni hao', isChorus: true, chorusEffect: 'beams',
        id: 'line-1', agentId: 'v1', blockIndex: 2, songPart: 'chorus', wordSegments: ['你好', '，', '你好', '！'],
        autoWordSegments: ['你', '好', '，', '你', '好', '！'],
        backgroundVocal: { text: 'ah', startTime: 1, endTime: 2, words: [word('ah', 1, 2)], agentId: 'v2' },
        backgroundVocals: [{ text: 'oh', startTime: 2, endTime: 2.5, words: [word('oh', 2, 2.5)], alternateTexts: [{ role: 'translation', text: '哦' }] }],
    }),
    line('e\u0301 👩🏽‍🚀 forever', 3, 5, [word('e\u0301', 3, 3.2), word('👩🏽‍🚀', 3.2, 3.4), word('forever', 3.4, 5, {
        syllables: [{ text: 'for', startTime: 3.4, endTime: 3.6, endsWithSpace: false, ruby: [{ text: 'ふぉ', startTime: 3.4, endTime: 3.6 }] }, { text: 'ever', startTime: 3.8, endTime: 5, obscene: true, emptyBeat: 2 }],
    })], { alternateTexts: [{ role: 'romanization', language: 'en', text: 'romaji' }, { role: 'translation', text: ' translation ' }] }),
    line('placeholder', 5.1, 5.22, [word('missing', 5.1, 5.22)], { translation: '//', romanization: '●●●' }),
    line('same same', 5.5, 7, [], { translation: 'same', romanization: 'same' }),
    line('long'.repeat(110), 7, 10, [], { translation: 'translated '.repeat(30), romanization: 'romanized '.repeat(24) }),
];
const theme = { primaryColor: '#203438', backgroundColor: '#eeeeee', accentColor: '#3b7ca4' };
const inputs = { fontPx: 36.5, translationFontPx: 18, fontStack: 'sans-serif', translationFontStack: 'serif', fontWeight: 600, translationFontWeight: 500, secondaryTranslationFontWeight: 400, maxWidthPx: 240, subtitleContentMode: 'both' };
const fontCases = ['sans', 'serif', 'mono', 'unknown'].flatMap(fontStyle => [
    { fontStyle },
    { fontStyle, fontWeight: 619, fontFamily: '  "Custom Face" ', fontFamilyStack: ['Custom Face', 'custom face', 'serif', "'Other Face'", 'esc"ape\\font', ''] },
]);
const wordColors = [{ word: '你好', color: '#aabbcc' }, { word: '你好，你好', color: '#112233' }, { word: 'for ever', color: '#445566' }, { word: 'hello', color: '#778899' }, { word: 'for', color: '#abcdef' }, { word: 'hello', color: '#ffffff' }];
let portraitLayers = [];
const portraitEvents = [['push', 'one', '1'], ['push', 'two', '2'], ['push', 'two', 'repeat'], ['push', 'three', '3'], ['push', 'four', '4'], ['push', 'five', '5'], ['settle', 'gone'], ['settle', '3'], ['settle', '5']].map(event => {
    portraitLayers = event[0] === 'push' ? portraits.pushMonetPortraitLayer(portraitLayers, event[1], event[2]) : portraits.settleMonetPortraitLayers(portraitLayers, event[1]);
    return { event, layers: portraitLayers, target: portraits.monetPortraitTargetSource(portraitLayers) };
});
const entriesAt = time => {
    const activeIndex = lines.findIndex(l => time >= l.startTime && time <= l.endTime);
    const recent = [...lines].reverse().find(l => l.endTime < time) ?? null;
    const next = lines.find(l => l.startTime > time) ?? null;
    return model.buildMonetVisibleLineEntries({ lines, currentLineIndex: activeIndex, activeLine: lines[activeIndex] ?? null, recentCompletedLine: recent, upcomingLine: next, currentTime: time });
};
const publicEntries = entries => entries.map(({ key, index, offset, status }) => ({ key, index, offset, status }));
const data = {
    baseline: '45d7d8a27afc7efb7a33308824def68329a86651',
    scope: 'Pure timing/token/subtitle/rail rules only; fixed synthetic text advances, no font or visual parity assertion.',
    document: { lines, title: '原始歌词', artist: 'Artist', isWordByWord: true, ttml: { timingMode: 'Word', agents: { v1: { id: 'v1', name: 'Singer', type: 'person' } } }, extension: { preserved: true } },
    tokens: lines.map(model.buildMonetDisplayTokens),
    timelines: lines.map(timing.buildLineGraphemeTimeline),
    hints: lines.map(hints.buildLineRenderHints),
    transitions: lines.map(l => { const h = hints.buildLineRenderHints(l); return hints.getLineTransitionTiming(h.rawDuration, h.lineTransitionMode, h.wordRevealMode); }),
    subtitles: lines.map(l => Object.fromEntries(['none', 'translation', 'romanization', 'both'].map(m => [m, model.resolveMonetSubtitleTracks(l, m)]))),
    genericSubtitles: lines.map(l => subtitles.resolveLyricSubtitleTracks(l, 'both')),
    inputs,
    layouts: lines.map(l => Object.fromEntries(['active', 'waiting', 'passed'].map(status => [status, model.measureMonetLineLayout({ line: l, status, ...inputs })]))),
    visible: [-1, 0, .06, .4, .5, 2, 3, 5.05, 5.22, 6, 8, 12].map(time => ({ time, entries: publicEntries(entriesAt(time)) })),
    scroll: [-4, 0, 3, 99].map(anchor => ({ anchor, entries: publicEntries(rail.buildScrollableRailEntries(lines, anchor, 2)) })),
    positioned: [.05, .3, 2, 5.05, 8].map(time => ({ time, entries: rail.buildPositionedEntries(entriesAt(time), { width: 360, height: 420 }, theme, inputs.fontPx, 26, inputs, 44, new Map()).map(e => ({ ...publicEntries([e])[0], y: e.y, scaledHeight: e.scaledHeight, tone: e.tone, layout: e.layout })) })),
    fill: [-1, 3.4, 3.5, 3.65, 3.8, 4, 4.9, 5, 6].map(time => ({ time, value: motion.resolveMonetFillWidth(time, 3.4, 5, [0, 11, 22, 33, 44, 55, 66, 77], timing.buildWordGraphemeTimings(lines[2].words[2])) })),
    cacheKeys: lines.map((line, index) => model.buildMonetLayoutCacheKey({ line, index, status: 'active' }, inputs)),
    fonts: fontCases.map(theme => ({ theme, lyric: fonts.resolveThemeFontStack(theme), translation: fonts.resolveThemeTranslationFontStack(theme), weight: fonts.resolveThemeFontWeight(theme, 600) })),
    weights: [null, 'bold', 40, 100, 104, 105, 619, 905].map(input => ({ input, value: fonts.normalizeFontWeight(input) })),
    colors: { wordColors, matchers: colors.prepareWordColorMatchers(wordColors), cases: lines.map(line => {
        const tokens = model.buildMonetDisplayTokens(line), ranges = colors.buildWordColorRanges(line.fullText, wordColors);
        return { text: line.fullText, ranges, tokenColors: Object.fromEntries(colors.resolveTokenColorMap(tokens, ranges)) };
    }), resolves: ['你', '你好', '你好，你好', 'hello!', 'ever', 'for', ''].flatMap(text => ['target-contains-token', 'bidirectional-contains', 'exact'].map(cjkMatchMode => ({ text, mode: cjkMatchMode, value: colors.resolveWordColor(text, wordColors, '#000000', { cjkMatchMode }) }))) },
    portraitEvents,
};
fs.writeFileSync(path.join(__dirname, '../test/fixtures/lyric_reference.json'), JSON.stringify(data, null, 2) + '\n');
process.stdout.write('Baseline lyric oracle regenerated; no visual parity claimed.\n');

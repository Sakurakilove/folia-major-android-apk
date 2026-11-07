const fs = require('node:fs');
const path = require('node:path');
const { baseline, load } = require('./original_source.cjs');

// Small original-function contract for each stride threshold, empty pages, Unicode mirrors, visible-first culling and grown explore prefixes.
const model = load('src/components/app/lattice/exploreLayout.ts');
const seats = load('src/components/app/lattice/lotSeats.ts');
const shapes = load('src/library/suites/bravais/bravaisWallShape.ts');
const kinds = ['song', 'playlist', 'mix', 'artist', 'album'];
const points = [{x:0,y:0},{x:-2100.5,y:870},{x:84012,y:-71234}];
const bounds = {left:-4200,right:2900,top:-1800,bottom:2100}, visible = {left:-1331,right:712,top:-781,bottom:900};
const datasets = [[],[1],[2,14],[13,7,1,4],[0,27,3,12,5,1,7]];
const cases = datasets.map((counts, caseIndex) => {
    let index = 0;
    const sections = counts.map((count, s) => ({key:`区🎵\ud800-${s}`,heading:`Section ${s}`,entries:Array.from({length:count},(_,i)=>({index:index++,kind:kinds[(i+s)%kinds.length]}))}));
    const metrics = {cellSize:128,gap:8}, layout = model.createExploreLayout(sections,metrics), lots = model.buildStrip(sections.filter(s=>s.entries.length));
    const nearest = [0,index-1,index+5].map(i=>({index:i,results:points.map(p=>layout.nearest(i,p))}));
    const active = nearest.find(r=>r.results[0])?.results[0];
    const origin = {column:-2,row:3};
    const shape = sections.some(s=>s.entries.length) ? shapes.createExploreShape(sections,origin) : shapes.BRAVAIS_BLOCK_SHAPE;
    const collected = shapes.collectShapeSlots(shape,bounds,73,visible);
    const extra = {key:'new',heading:'New',entries:[{index:index+1,kind:'song'}]};
    const grown = sections.some(s=>s.entries.length) ? shapes.createExploreShape([...sections,extra],origin) : shape;
    return {sections,metrics,origin,bounds,visible,points,lots,near:layout.near(bounds,200),nearest,
        grownLayout:active?[...layout.grown(active)]:[],steps:active?layout.stepCandidates(active):[],
        sectionAt:points.map(p=>layout.sectionAt(p)),sectionStart:sections.map((_,i)=>layout.sectionStart(i,points[1])),
        shape:{id:shape.id,size:shape.blockSize,slots:collected,
            address:collected.map(s=>({entry:shape.entryAt?.(s)??null,heading:shape.headingAt(s),key:shape.blockKey(s.column,s.row)})),
            grown:collected.slice(0,6).map(s=>shape.grownBlock(s.column,s.row,s.slotIndex)),
            nearest:nearest.map(r=>({index:r.index,results:points.map(p=>shape.nearestEntry?.(r.index,p)??null)})),
            starts:points.map(p=>shape.startKeyAt(p)),grownPrefix:shapes.isGrownExploreShape(shape,grown),
            split:shapes.splitGrownSlots(shape,grown,collected),extra},caseIndex};
});
const lotCases = [1,2,3,7,13].map(count=>({count,key:'绫😀\ud800',part:count-1,
    mirrors:seats.mirrorsOf('绫😀\ud800',count-1)})).map(c=>({...c,...seats.cutLot(c.count,c.mirrors),grown:seats.cutGrownLot(c.count,c.mirrors,c.count-1)}));
fs.writeFileSync(path.join(__dirname,'../test/fixtures/explore_reference.json'),JSON.stringify({baseline,cases,lotCases},null,2)+'\n');
console.log('Exported five original explore layouts/shapes and five exact lot/Unicode assignment cases.');

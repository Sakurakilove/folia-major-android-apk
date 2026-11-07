const fs=require('node:fs'),path=require('node:path');
const {baseline,load}=require('./original_source.cjs');

// Execute the actual locked source helpers; input pixel patterns are small deterministic fixtures, not a second implementation of the algorithms.
const tone=load('src/library/suites/bravais/bravaisArtistTone.ts'),art=load('src/library/suites/bravais/bravaisAlbumWall.ts');
const tones=[[],[255,0,0,127],[150,150,150,255],[100,151,200,255,101,152,201,128],
  [250,0,1,255],[100,110,100,255],[100,111,100,255],[254,0,1,255,255,1,2,255]].map(pixels=>{
  const average=tone.averagePixelColor(new Uint8ClampedArray(pixels));
  return {pixels,result:average?tone.resolveArtistToneLight(average):null};
});
const spots=[];
for(const pattern of ['flat','stripes','gradient']) for(const side of [10,50]){
  const pixels=new Uint8ClampedArray(side*side*4);
  for(let y=0;y<side;y++)for(let x=0;x<side;x++){
    const i=(y*side+x)*4;
    pixels[i]=pattern==='flat'?128:pattern==='stripes'?(x%3===0?255:0):Math.floor(x*255/side);
    pixels[i+1]=pattern==='gradient'?Math.floor(y*255/side):64;pixels[i+2]=128;pixels[i+3]=255;
  }
  spots.push({pattern,side,result:art.findCoverSpots(pixels,side)});
}
const placements=[];
for(const [column,row]of [[0,0],[-2,3],[17,-9]])for(const [width,height]of[[128,264],[808,808]]){
  const rect={x:column*1632+117,y:row*1088-58,width,height};
  for(const seed of ['track:1','歌😀','\ud800']){
    const shard=art.shardPlacement([{x:.35,y:.4},{x:.65,y:.6}],seed,rect);
    placements.push({column,row,rect,seed,mosaic:art.mosaicPlacement(rect,{column,row}),shard,
      css:Object.fromEntries(Object.entries(shard).map(([k,v])=>[k,Number(v.toFixed(1))]))});
  }
}
const target=path.join(__dirname,'../test/fixtures/wall_art_reference.json');
fs.writeFileSync(target,JSON.stringify({baseline,tones,spots,placements})+'\n');
console.log('Exported original artist tone, Float32 detail spots and album placements.');

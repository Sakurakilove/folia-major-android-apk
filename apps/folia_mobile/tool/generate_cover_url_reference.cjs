const fs=require('node:fs');
const path=require('node:path');
const {baseline,load}=require('./original_source.cjs');

// Original cover helpers execute against Node's WHATWG URL, including escape/query/opaque-host cases that Dart Uri rewrites differently.
const policy=load('src/utils/coverUrl.ts'),sources=[null,'','  ',
    'https://p1.music.126.net/a%7Eb.jpg?old=1#h',
    'https:p2.music.126.net/封面.jpg?param=300y300',
    'https://y.gtimg.cn/music/photo_new/T002R300x300M000abc.jpg?v=%7E#f',
    'https://y.qq.com/T001M000abc.jpg',
    'http://imge.kugou.com/stdmusic/200/abc.jpg',
    'https://cdn.kgimg.com/stdmusic/1024/abc.jpg?x=a%20b',
    'https://img1.kuwo.cn/star/albumcover/240/abc.jpg',
    'https://img.kuwo.cn/star/starheads/1200/abc.jpg',
    'https://example.test/getCoverArt?size=128&label=a%20b&other=~&bad=%FF&size=256#f',
    'https://例え.テスト/getCoverArt?size=0x100&label=中文',
    'https://example.test/getCoverArt?size=%C2%A0512%C2%A0&%FF=bad&%EF%BF%BD=other',
    'folia-cover://AbC/cover/1?size=256&v=~#f',
    '/__folia_cover/a%7E.jpg?size=1&v=~#hash',
    'not-a-url126.net?param=1',
    'test://p2.music.126.net/a.jpg?x=1',
    'data:image/png;base64,AAAA','blob:https://example.test/opaque','file:///tmp/cover.jpg',
    'mailto:example@example.test','https://example.test/other.jpg?label=~',
    '\u0085https://p1.music.126.net/a.jpg\u0085','\uFEFF https://p1.music.126.net/a.jpg\u00A0'];
const cases=[];
for (const source of sources) for (const size of [64,256,300,512,800,1024,2048,NaN,Infinity]) {
    cases.push({source,size:Number.isFinite(size)?size:String(size),
        original:policy.getOriginalCoverUrl(source),sized:policy.getSizedCoverUrl(source,size),
        identity:policy.getCoverIdentity(source),description:policy.describeCoverUrl(source),
        resizedDescription:policy.describeCoverUrl(policy.getSizedCoverUrl(source,size)),
        localSize:policy.resolveLocalCoverThumbnailSize(size),
        step:Number.isFinite(policy.resolveCoverSizeStep(size))?policy.resolveCoverSizeStep(size):'Infinity'});
}
(async()=>{
    const dataCases=[];
    for (const source of ['data:,hello%20world','data:application/octet-stream,%00%FF+A%23B#fragment',
        'data:text/plain;base64,QQ==','data:text/plain; BASE64,QUI=','data:;base64,QUJDRA',
        'data:;base64,QQ==%0A','data:;base64,QQ=','data:;base64,Q','data:;base64,=QQ=',
        'data:;base64,AB==','data:;base64,ABC=','data:;base64,',
        'data:text/plain,中文','data:;base64,QQ==#ignored','data:no-comma']) {
        const normalized=new URL(source).href;
        try { dataCases.push({source,normalized,bytes:[...new Uint8Array(await (await fetch(source)).arrayBuffer())]}); }
        catch { dataCases.push({source,normalized,bytes:null}); }
    }
    fs.writeFileSync(path.join(__dirname,'../test/fixtures/cover_url_reference.json'),JSON.stringify({baseline,
        ada:process.versions.ada,scope:'URL/functions, inline byte parsing and ownership only, not network images or device WebView parity.',cases,dataCases})+'\n');
    console.log(`${cases.length} original provider cover URL cases and ${dataCases.length} WHATWG inline byte cases generated.`);
})();

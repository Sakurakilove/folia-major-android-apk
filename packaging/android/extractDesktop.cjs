const fs = require('node:fs');
const path = require('node:path');
const { parse } = require('../../node_modules/acorn');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'electron/main.cjs'), 'utf8');
const ast = parse(source, { ecmaVersion: 'latest', sourceType: 'script' });
const functions = new Map(ast.body.filter(node => node.type === 'FunctionDeclaration').map(node => [node.id.name, source.slice(node.start, node.end)]));
const names = ['getConfiguredObsBrowserSourcePort', 'isObsBrowserSourceEnabled', 'getObsBrowserSourceToken',
    'buildObsBrowserSourceUrl', 'buildObsBrowserSourceStatus', 'broadcastObsBrowserSourceStatus',
    'getStaticContentType', 'sendObsJson', 'sendObsText', 'matchesObsBrowserSourceToken', 'sendObsEvent',
    'sendSerializedObsEvent', 'broadcastObsBrowserSourceEvent', 'sendObsBrowserSourceBootstrapEvents',
    'serveObsStaticFile', 'handleObsBrowserSourceHttpRequest', 'startObsBrowserSourceServerIfNeeded',
    'stopObsBrowserSourceServer', 'syncObsBrowserSourceServerState', 'isElectronDevRuntime'];
for (const name of names) if (!functions.has(name)) throw new Error('Upstream OBS function changed: ' + name);
const header = `// Generated from the pinned desktop source by extractDesktop.cjs.\nconst fs=require('node:fs'), path=require('node:path'), http=require('node:http'), crypto=require('node:crypto');
module.exports=({store,mainWindow})=>{
const OBS_BROWSER_SOURCE_PORT_SETTING_KEY='OBS_BROWSER_SOURCE_PORT', OBS_BROWSER_SOURCE_ENABLED_SETTING_KEY='OBS_BROWSER_SOURCE_ENABLED', OBS_BROWSER_SOURCE_TOKEN_SETTING_KEY='OBS_BROWSER_SOURCE_TOKEN';
const DEFAULT_OBS_BROWSER_SOURCE_PORT=32108;
let obsBrowserSourceServer=null, latestObsBrowserSourceConfig=store.get('ANDROID_WALLPAPER_LAST_CONFIG',null), latestObsBrowserSourceClock=null, latestObsBrowserSourceAudio=null;
const obsBrowserSourceClients=new Set();\n`;
const footer = `\nvoid syncObsBrowserSourceServerState();
return { getObsBrowserSourceStatus:buildObsBrowserSourceStatus,
setObsBrowserSourceEnabled:enabled=>{store.set(OBS_BROWSER_SOURCE_ENABLED_SETTING_KEY,Boolean(enabled));return syncObsBrowserSourceServerState();},
regenerateObsBrowserSourceToken:()=>{store.set(OBS_BROWSER_SOURCE_TOKEN_SETTING_KEY,crypto.randomBytes(32).toString('base64url'));broadcastObsBrowserSourceStatus();return buildObsBrowserSourceStatus();},
publishObsBrowserSourceConfig:config=>{latestObsBrowserSourceConfig=config||null;store.set('ANDROID_WALLPAPER_LAST_CONFIG',latestObsBrowserSourceConfig);if(config)broadcastObsBrowserSourceEvent('config',config);return true;},
publishObsBrowserSourceClock:clock=>{latestObsBrowserSourceClock=clock||null;if(clock)broadcastObsBrowserSourceEvent('clock',clock);return true;},
publishObsBrowserSourceAudio:audio=>{latestObsBrowserSourceAudio=audio||null;if(audio)broadcastObsBrowserSourceEvent('audio',audio);return true;}};};\n`;
fs.mkdirSync(path.join(__dirname, 'runtime/generated'), { recursive: true });
// The generated file is one directory below runtime, just like the original main below the app root.
fs.writeFileSync(path.join(__dirname, 'runtime/generated/obs.cjs'), header + names.map(name => functions.get(name)).join('\n') + footer);

const lyricNames = ['isAllowedLyricProxyHost', 'isAmllDbHost', 'proxyLyricRequest'];
for (const name of lyricNames) if (!functions.has(name)) throw new Error('Upstream lyric proxy changed: ' + name);
fs.writeFileSync(path.join(__dirname, 'runtime/generated/lyrics.cjs'), '// Generated from electron/main.cjs.\nconst AMLL_API_TIMEOUT_MS=5000;\n' + lyricNames.map(name => functions.get(name)).join('\n') + '\nmodule.exports={fetchLyricProxy:proxyLyricRequest};\n');
const cacheNames = ['getAudioCacheDirectory', 'getCoverCacheDirectory', 'getAudioCacheBaseName', 'getAudioCachePaths', 'getCoverCachePaths',
    'ensureAudioCacheDirectory', 'hasAudioCacheEntry', 'readAudioCacheEntry', 'listAudioCacheEntries', 'removeAudioCacheEntry',
    'listMediaCacheEntries', 'pruneMediaCache', 'writeAudioCacheEntry', 'getAudioCacheUsageBytes', 'getAudioCacheStats', 'clearAudioCacheDirectory',
    'ensureCoverCacheDirectory', 'readCoverCacheEntry', 'writeCoverCacheEntry', 'removeCoverCacheEntry', 'getCoverCacheUsageBytes', 'clearCoverCacheDirectory'];
for (const name of cacheNames) if (!functions.has(name)) throw new Error('Upstream media cache changed: ' + name);
const cacheHeader = `// Generated from electron/main.cjs; preserve its shared media budget and cover validation.
const fs=require('node:fs'),fsp=fs.promises,path=require('node:path'),crypto=require('node:crypto');
module.exports=({getConfiguredCacheDirectory,transcodeService,spotifyApiBridge,pruneHelpers=require('../electron/audioCachePrune.cjs'),removeHelpers=require('../electron/audioCacheRemove.cjs')})=>{
const {resolveCacheLimit,selectEvictions}=pruneHelpers;
const {removeAudioCacheFileOfSize}=removeHelpers;\n`;
const cacheFooter = `\nreturn { _pruneAudioCache:pruneMediaCache,
getAudioCache:readAudioCacheEntry,hasAudioCache:hasAudioCacheEntry,
saveAudioCache:async(...args)=>{await writeAudioCacheEntry(...args);return true;},
removeAudioCache:(key,size)=>{const {dataPath,metaPath}=getAudioCachePaths(key);return removeAudioCacheFileOfSize(dataPath,metaPath,size);},
getAudioCacheUsage:getAudioCacheUsageBytes,getAudioCacheStats,
clearAudioCache:async()=>{await clearAudioCacheDirectory();return true;},
getCoverCache:readCoverCacheEntry,saveCoverCache:async(...args)=>{await writeCoverCacheEntry(...args);return true;},
removeCoverCache:removeCoverCacheEntry,getCoverCacheUsage:getCoverCacheUsageBytes,
clearCoverCache:async()=>{await clearCoverCacheDirectory();return true;}};};\n`;
fs.writeFileSync(path.join(__dirname, 'runtime/generated/mediaCache.cjs'), cacheHeader + cacheNames.map(name => functions.get(name)).join('\n') + cacheFooter);
const fontNames = ['normalizeDebugSelector', 'withMainWindowDebugger', 'getRenderedFontReport'];
for (const name of fontNames) if (!functions.has(name)) throw new Error('Upstream font inspector changed: ' + name);
fs.writeFileSync(path.join(__dirname, 'runtime/generated/fonts.cjs'), '// Generated from electron/main.cjs.\nmodule.exports=({mainWindow})=>{\n' + fontNames.map(name => functions.get(name)).join('\n') + '\nreturn getRenderedFontReport;};\n');

// Preserve public setting defaults and legacy boolean normalization from the desktop implementation.
const publicSettingsNode = ast.body.find(node => node.type === 'FunctionDeclaration' && node.id.name === 'getPublicSettings');
const settingKeys = [...new Set(publicSettingsNode.body.body.find(node => node.type === 'ReturnStatement').argument.properties
    .filter(property => property.computed && property.key.type === 'Identifier').map(property => property.key.name))];
const settingConstants = new Map(ast.body.filter(node => node.type === 'VariableDeclaration').flatMap(node => node.declarations)
    .filter(node => node.id.type === 'Identifier' && node.init?.type === 'Literal').map(node => [node.id.name, node.init.value]));
for (const [key, value] of Object.entries(require('../../electron/remoteControlWindowSettings.cjs'))) if (typeof value === 'string') settingConstants.set(key, value);
for (const key of settingKeys) if (!settingConstants.has(key)) throw new Error('Upstream public setting constant changed: ' + key);
const settingsHeader = `// Generated from electron/main.cjs by extractDesktop.cjs.\nmodule.exports=({store,aiCredentials,app})=>{\n`
    + settingKeys.map(key => `const ${key}=${JSON.stringify(settingConstants.get(key))};`).join('\n')
    + `\nconst wallpaperWindowsAttachMode=null;\nconst isWallpaperModeEnabled=()=>require('./../electron/wallpaper/wallpaperWatchdog.cjs').isWallpaperModeEnabled(store);\nconst getCurrentReleaseChannel=()=>require('./../electron/updateChannels.cjs').resolveReleaseChannel(app.getVersion(),store.get(UPDATE_CHANNEL_SETTING_KEY)||'realeco');\n`;
fs.writeFileSync(path.join(__dirname, 'runtime/generated/publicSettings.cjs'), settingsHeader + functions.get('readStoredBoolean') + '\n' + functions.get('getPublicSettings') + '\nreturn Object.assign(getPublicSettings,{readStoredBoolean});};\n');

// Extract the original save-settings boolean key list and update-lane validation instead of maintaining another list.
const saveHandler = ast.body.find(node => node.type === 'ExpressionStatement'
    && node.expression?.type === 'CallExpression' && node.expression.callee?.object?.name === 'ipcMain'
    && node.expression.callee?.property?.name === 'handle' && node.expression.arguments[0]?.value === 'save-settings')?.expression.arguments[1];
const booleanNormalization = saveHandler?.body.body.find(node => node.type === 'IfStatement'
    && source.slice(node.consequent.start, node.consequent.end).trim() === '{\n    nextValue = Boolean(value);\n  }');
if (!booleanNormalization || !functions.has('normalizeUpdateChannelSelection')) throw new Error('Upstream setting normalization changed');
const booleanNames = [...source.slice(booleanNormalization.test.start, booleanNormalization.test.end).matchAll(/key\s*===\s*([A-Z_]+)/g)].map(match => match[1]);
if (!booleanNames.length || booleanNames.some(key => !settingConstants.has(key))) throw new Error('Upstream boolean setting keys changed');
fs.writeFileSync(path.join(__dirname, 'runtime/generated/normalizeSettings.cjs'),
    '// Generated from electron/main.cjs by extractDesktop.cjs.\n' + functions.get('normalizeUpdateChannelSelection')
    + '\nconst booleanKeys=new Set(' + JSON.stringify(booleanNames.map(key => settingConstants.get(key))) + ');\n'
    + `module.exports=(key,value)=>{if(key==='UPDATE_CHANNEL'){const channel=normalizeUpdateChannelSelection(value);return {accepted:channel!==null,value:channel};}return {accepted:true,value:booleanKeys.has(key)?Boolean(value):value};};\n`);

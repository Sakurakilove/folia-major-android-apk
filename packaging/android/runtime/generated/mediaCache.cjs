// Generated from electron/main.cjs; preserve its shared media budget and cover validation.
const fs=require('node:fs'),fsp=fs.promises,path=require('node:path'),crypto=require('node:crypto');
module.exports=({getConfiguredCacheDirectory,transcodeService,spotifyApiBridge,pruneHelpers=require('../electron/audioCachePrune.cjs'),removeHelpers=require('../electron/audioCacheRemove.cjs')})=>{
const {resolveCacheLimit,selectEvictions}=pruneHelpers;
const {removeAudioCacheFileOfSize}=removeHelpers;
function getAudioCacheDirectory() {
  return path.join(getConfiguredCacheDirectory(), 'audio');
}
function getCoverCacheDirectory() {
  return path.join(getConfiguredCacheDirectory(), 'cover');
}
function getAudioCacheBaseName(cacheKey) {
  return crypto.createHash('sha256').update(cacheKey).digest('hex');
}
function getAudioCachePaths(cacheKey) {
  const baseName = getAudioCacheBaseName(cacheKey);
  const directory = getAudioCacheDirectory();

  return {
    directory,
    dataPath: path.join(directory, `${baseName}.bin`),
    metaPath: path.join(directory, `${baseName}.json`),
  };
}
function getCoverCachePaths(cacheKey) {
  const baseName = getAudioCacheBaseName(cacheKey);
  const directory = getCoverCacheDirectory();

  return {
    directory,
    dataPath: path.join(directory, `${baseName}.bin`),
    metaPath: path.join(directory, `${baseName}.json`),
  };
}
async function ensureAudioCacheDirectory() {
  await fsp.mkdir(getAudioCacheDirectory(), { recursive: true });
}
async function hasAudioCacheEntry(cacheKey) {
  const { dataPath } = getAudioCachePaths(cacheKey);

  try {
    await fsp.access(dataPath, fs.constants.F_OK);
    return true;
  } catch {
    return false;
  }
}
async function readAudioCacheEntry(cacheKey) {
  const { dataPath, metaPath } = getAudioCachePaths(cacheKey);

  try {
    const [dataBuffer, rawMeta] = await Promise.all([
      fsp.readFile(dataPath),
      fsp.readFile(metaPath, 'utf-8').catch(() => null),
    ]);

    // Mark it as recently used, so pruning evicts by last play rather than by first download.
    // Access time would say this without a write, but Windows ships with atime updates off, so
    // the only field that survives a round trip is the one we set ourselves.
    const now = new Date();
    fsp.utimes(dataPath, now, now).catch(() => {});

    let mimeType = 'audio/mpeg';
    if (rawMeta) {
      try {
        const parsedMeta = JSON.parse(rawMeta);
        if (typeof parsedMeta.mimeType === 'string' && parsedMeta.mimeType.trim()) {
          mimeType = parsedMeta.mimeType;
        }
      } catch {
        // Ignore malformed metadata and keep the default content type.
      }
    }

    return {
      found: true,
      data: dataBuffer,
      mimeType,
    };
  } catch {
    return {
      found: false,
      data: null,
      mimeType: null,
    };
  }
}
async function listAudioCacheEntries() {
  const audioDirectory = getAudioCacheDirectory();
  try {
    const names = (await fsp.readdir(audioDirectory)).filter((name) => name.endsWith('.bin'));
    return Promise.all(names.map(async (name) => {
      const stat = await fsp.stat(path.join(audioDirectory, name));
      return { name, size: stat.size, usedAt: stat.mtimeMs };
    }));
  } catch {
    return [];
  }
}
async function removeAudioCacheEntry(name) {
  if (!/^[a-zA-Z0-9_-]+\.bin$/.test(String(name || ''))) return;
  const base = path.join(getAudioCacheDirectory(), name.replace(/\.bin$/, ''));
  await Promise.allSettled([
    fsp.rm(`${base}.bin`, { force: true }),
    fsp.rm(`${base}.json`, { force: true }),
  ]);
}
async function listMediaCacheEntries() {
  const [audioEntries, transcodeEntries, spotifyEntries] = await Promise.all([
    listAudioCacheEntries(),
    transcodeService.listCacheEntries(),
    spotifyApiBridge.audioFiles.list(),
  ]);
  return [
    ...audioEntries.map(entry => ({ ...entry, name: `audio:${entry.name}` })),
    ...transcodeEntries.map(entry => ({ ...entry, name: `transcode:${entry.name}` })),
    ...spotifyEntries.map(entry => ({ ...entry, name: `spotify:${entry.name}` })),
  ];
}
async function pruneMediaCache(limitBytes, protectedTranscodeEntry = null) {
  const resolvedLimit = resolveCacheLimit(limitBytes);
  if (resolvedLimit === Infinity) return;

  try {
    let entries = await listMediaCacheEntries();
    // Entries the renderer is streaming are unevictable but still spend the budget: a fully
    // buffered media element stops touching its file, so LRU alone would drop it mid-playback.
    const protectedNames = new Set(transcodeService.getPinnedCacheKeys().map(key => `transcode:${key}`));
    if (protectedTranscodeEntry) protectedNames.add(`transcode:${protectedTranscodeEntry.cacheKey}`);
    const protectedEntries = entries.filter(entry => protectedNames.has(entry.name));
    let protectedBytes = protectedEntries.reduce((total, entry) => total + entry.size, 0);
    if (protectedTranscodeEntry && !protectedEntries.some(entry => entry.name === `transcode:${protectedTranscodeEntry.cacheKey}`)) {
      protectedBytes += protectedTranscodeEntry.size;
    }
    entries = entries.filter(entry => !protectedNames.has(entry.name));
    const effectiveLimit = protectedBytes > 0 ? Math.max(1, resolvedLimit - protectedBytes) : resolvedLimit;

    for (const name of selectEvictions(entries, effectiveLimit)) {
      if (name.startsWith('audio:')) await removeAudioCacheEntry(name.slice('audio:'.length));
      else if (name.startsWith('transcode:')) await transcodeService.removeCacheEntry(name.slice('transcode:'.length));
      else if (name.startsWith('spotify:')) await spotifyApiBridge.audioFiles.remove(name.slice('spotify:'.length));
    }
  } catch (error) {
    console.warn('[AudioCache] Failed to prune media cache directories', error);
  }
}
async function writeAudioCacheEntry(cacheKey, data, mimeType, limitBytes) {
  const { dataPath, metaPath } = getAudioCachePaths(cacheKey);
  await ensureAudioCacheDirectory();

  const buffer = Buffer.isBuffer(data)
    ? data
    : Buffer.from(data instanceof ArrayBuffer ? new Uint8Array(data) : data);

  await Promise.all([
    fsp.writeFile(dataPath, buffer),
    fsp.writeFile(metaPath, JSON.stringify({
      cacheKey,
      mimeType: mimeType || 'audio/mpeg',
      size: buffer.byteLength,
      updatedAt: Date.now(),
    }), 'utf-8'),
  ]);

  await pruneMediaCache(limitBytes);
}
async function getAudioCacheUsageBytes() {
  try {
    return (await listMediaCacheEntries()).reduce((total, entry) => total + entry.size, 0);
  } catch {
    return 0;
  }
}
async function getAudioCacheStats() {
  try {
    const entries = await listMediaCacheEntries();

    return {
      size: entries.reduce((total, entry) => total + entry.size, 0),
      count: entries.length,
    };
  } catch {
    return {
      size: 0,
      count: 0,
    };
  }
}
async function clearAudioCacheDirectory() {
  try {
    await Promise.all([
      fsp.rm(getAudioCacheDirectory(), { recursive: true, force: true }),
      transcodeService.clearCache(),
      spotifyApiBridge.audioFiles.clear(),
    ]);
  } catch (error) {
    console.warn('[AudioCache] Failed to clear cache directory', error);
  }
}
async function ensureCoverCacheDirectory() {
  await fsp.mkdir(getCoverCacheDirectory(), { recursive: true });
}
async function readCoverCacheEntry(cacheKey) {
  const { dataPath, metaPath } = getCoverCachePaths(cacheKey);
  try {
    const [dataBuffer, rawMeta] = await Promise.all([
      fsp.readFile(dataPath),
      fsp.readFile(metaPath, 'utf-8').catch(() => null),
    ]);
    if (dataBuffer.byteLength === 0) {
      await Promise.allSettled([fsp.rm(dataPath, { force: true }), fsp.rm(metaPath, { force: true })]);
      return { found: false, data: null, mimeType: null };
    }
    try {
      const parsedMeta = rawMeta ? JSON.parse(rawMeta) : null;
      const validMeta = parsedMeta
        && parsedMeta.cacheKey === cacheKey
        && typeof parsedMeta.mimeType === 'string'
        && parsedMeta.mimeType.startsWith('image/')
        && parsedMeta.size === dataBuffer.byteLength;
      if (!validMeta) throw new Error('Invalid cover cache metadata');
      return { found: true, data: dataBuffer, mimeType: parsedMeta.mimeType };
    } catch {
      await Promise.allSettled([fsp.rm(dataPath, { force: true }), fsp.rm(metaPath, { force: true })]);
      return { found: false, data: null, mimeType: null };
    }
  } catch {
    return { found: false, data: null, mimeType: null };
  }
}
async function writeCoverCacheEntry(cacheKey, data, mimeType) {
  const { dataPath, metaPath } = getCoverCachePaths(cacheKey);
  await ensureCoverCacheDirectory();
  const buffer = Buffer.isBuffer(data)
    ? data
    : Buffer.from(data instanceof ArrayBuffer ? new Uint8Array(data) : data);
  if (buffer.byteLength === 0) throw new Error('Cannot persist an empty cover payload');
  if (typeof mimeType !== 'string' || !mimeType.startsWith('image/')) {
    throw new Error('Cover cache only accepts image payloads');
  }
  await Promise.all([
    fsp.writeFile(dataPath, buffer),
    fsp.writeFile(metaPath, JSON.stringify({
      cacheKey,
      mimeType: mimeType || 'application/octet-stream',
      size: buffer.byteLength,
      updatedAt: Date.now(),
    }), 'utf-8'),
  ]);
}
async function removeCoverCacheEntry(cacheKey) {
  const { dataPath, metaPath } = getCoverCachePaths(cacheKey);
  await Promise.allSettled([fsp.rm(dataPath, { force: true }), fsp.rm(metaPath, { force: true })]);
}
async function getCoverCacheUsageBytes() {
  try {
    const entries = await fsp.readdir(getCoverCacheDirectory(), { withFileTypes: true });
    let total = 0;
    for (const entry of entries) {
      if (!entry.isFile() || !entry.name.endsWith('.bin')) continue;
      total += (await fsp.stat(path.join(getCoverCacheDirectory(), entry.name))).size;
    }
    return total;
  } catch {
    return 0;
  }
}
async function clearCoverCacheDirectory() {
  try {
    await fsp.rm(getCoverCacheDirectory(), { recursive: true, force: true });
  } catch (error) {
    console.warn('[CoverCache] Failed to clear cache directory', error);
  }
}
return { _pruneAudioCache:pruneMediaCache,
getAudioCache:readAudioCacheEntry,hasAudioCache:hasAudioCacheEntry,
saveAudioCache:async(...args)=>{await writeAudioCacheEntry(...args);return true;},
removeAudioCache:(key,size)=>{const {dataPath,metaPath}=getAudioCachePaths(key);return removeAudioCacheFileOfSize(dataPath,metaPath,size);},
getAudioCacheUsage:getAudioCacheUsageBytes,getAudioCacheStats,
clearAudioCache:async()=>{await clearAudioCacheDirectory();return true;},
getCoverCache:readCoverCacheEntry,saveCoverCache:async(...args)=>{await writeCoverCacheEntry(...args);return true;},
removeCoverCache:removeCoverCacheEntry,getCoverCacheUsage:getCoverCacheUsageBytes,
clearCoverCache:async()=>{await clearCoverCacheDirectory();return true;}};};

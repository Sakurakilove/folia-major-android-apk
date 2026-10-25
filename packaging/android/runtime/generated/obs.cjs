// Generated from the pinned desktop source by extractDesktop.cjs.
const fs=require('node:fs'), path=require('node:path'), http=require('node:http'), crypto=require('node:crypto');
module.exports=({store,mainWindow})=>{
const OBS_BROWSER_SOURCE_PORT_SETTING_KEY='OBS_BROWSER_SOURCE_PORT', OBS_BROWSER_SOURCE_ENABLED_SETTING_KEY='OBS_BROWSER_SOURCE_ENABLED', OBS_BROWSER_SOURCE_TOKEN_SETTING_KEY='OBS_BROWSER_SOURCE_TOKEN';
const DEFAULT_OBS_BROWSER_SOURCE_PORT=32108;
let obsBrowserSourceServer=null, latestObsBrowserSourceConfig=store.get('ANDROID_WALLPAPER_LAST_CONFIG',null), latestObsBrowserSourceClock=null, latestObsBrowserSourceAudio=null;
const obsBrowserSourceClients=new Set();
function getConfiguredObsBrowserSourcePort() {
  const storedPort = Number(store.get(OBS_BROWSER_SOURCE_PORT_SETTING_KEY));
  if (Number.isInteger(storedPort) && storedPort > 0 && storedPort <= 65535) {
    return storedPort;
  }
  return DEFAULT_OBS_BROWSER_SOURCE_PORT;
}
function isObsBrowserSourceEnabled() {
  return Boolean(store.get(OBS_BROWSER_SOURCE_ENABLED_SETTING_KEY));
}
function getObsBrowserSourceToken({ generateIfMissing = false } = {}) {
  const existing = store.get(OBS_BROWSER_SOURCE_TOKEN_SETTING_KEY);
  if (typeof existing === 'string' && existing.trim()) {
    return existing;
  }

  if (!generateIfMissing) {
    return null;
  }

  const nextToken = crypto.randomBytes(32).toString('base64url');
  store.set(OBS_BROWSER_SOURCE_TOKEN_SETTING_KEY, nextToken);
  return nextToken;
}
function buildObsBrowserSourceUrl() {
  const token = getObsBrowserSourceToken({ generateIfMissing: isObsBrowserSourceEnabled() });
  if (!token) {
    return null;
  }

  return `http://127.0.0.1:${getConfiguredObsBrowserSourcePort()}/obs?obs=1&token=${encodeURIComponent(token)}`;
}
function buildObsBrowserSourceStatus() {
  const token = getObsBrowserSourceToken({ generateIfMissing: isObsBrowserSourceEnabled() });
  return {
    enabled: isObsBrowserSourceEnabled(),
    port: getConfiguredObsBrowserSourcePort(),
    token,
    url: token ? buildObsBrowserSourceUrl() : null,
    clientCount: obsBrowserSourceClients.size,
  };
}
function broadcastObsBrowserSourceStatus() {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('obs-browser-source-status-changed', buildObsBrowserSourceStatus());
  }
}
function getStaticContentType(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  if (extension === '.html') return 'text/html; charset=utf-8';
  if (extension === '.js' || extension === '.mjs') return 'text/javascript; charset=utf-8';
  if (extension === '.css') return 'text/css; charset=utf-8';
  if (extension === '.json') return 'application/json; charset=utf-8';
  if (extension === '.svg') return 'image/svg+xml';
  if (extension === '.png') return 'image/png';
  if (extension === '.jpg' || extension === '.jpeg') return 'image/jpeg';
  if (extension === '.webp') return 'image/webp';
  if (extension === '.woff2') return 'font/woff2';
  if (extension === '.woff') return 'font/woff';
  return 'application/octet-stream';
}
function sendObsJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify(payload));
}
function sendObsText(res, statusCode, text, contentType = 'text/plain; charset=utf-8') {
  res.writeHead(statusCode, {
    'Content-Type': contentType,
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(text);
}
function matchesObsBrowserSourceToken(requestUrl) {
  const expectedToken = getObsBrowserSourceToken({ generateIfMissing: false });
  if (!expectedToken) {
    return false;
  }
  return requestUrl.searchParams.get('token') === expectedToken;
}
function sendObsEvent(res, eventName, payload) {
  sendSerializedObsEvent(res, eventName, JSON.stringify(payload));
}
function sendSerializedObsEvent(res, eventName, serializedPayload) {
  if (res.destroyed || res.writableEnded) return;
  if (res.foliaObsWaitingForDrain) {
    // These are state snapshots, not commands: preserve the latest config/clock/audio only.
    res.foliaObsPending.set(eventName, serializedPayload);
    return;
  }
  if (res.write(`event: ${eventName}\ndata: ${serializedPayload}\n\n`)) return;
  res.foliaObsWaitingForDrain = true;
  res.foliaObsPending = new Map();
  res.once('drain', () => {
    res.foliaObsWaitingForDrain = false;
    const pending = res.foliaObsPending;
    res.foliaObsPending = new Map();
    for (const name of ['config', 'clock', 'audio']) {
      if (pending.has(name)) sendSerializedObsEvent(res, name, pending.get(name));
    }
  });
}
function broadcastObsBrowserSourceEvent(eventName, payload) {
  const serializedPayload = JSON.stringify(payload);
  for (const client of Array.from(obsBrowserSourceClients)) {
    sendSerializedObsEvent(client, eventName, serializedPayload);
  }
}
function sendObsBrowserSourceBootstrapEvents(res) {
  if (latestObsBrowserSourceConfig) {
    sendObsEvent(res, 'config', latestObsBrowserSourceConfig);
  }
  if (latestObsBrowserSourceClock) {
    sendObsEvent(res, 'clock', latestObsBrowserSourceClock);
  }
  if (latestObsBrowserSourceAudio) {
    sendObsEvent(res, 'audio', latestObsBrowserSourceAudio);
  }
}
async function serveObsStaticFile(req, res, pathname) {
  const distRoot = path.resolve(__dirname, '../dist');
  const normalizedPath = pathname === '/' || pathname === '/obs'
    ? '/index.html'
    : pathname;
  const requestedPath = path.resolve(distRoot, `.${decodeURIComponent(normalizedPath)}`);

  if (!requestedPath.startsWith(distRoot)) {
    sendObsText(res, 403, 'Forbidden');
    return;
  }

  try {
    const stat = await fs.promises.stat(requestedPath);
    if (!stat.isFile()) {
      sendObsText(res, 404, 'Not found');
      return;
    }

    res.writeHead(200, {
      'Content-Type': getStaticContentType(requestedPath),
      'Cache-Control': requestedPath.endsWith('index.html') ? 'no-store' : 'public, max-age=31536000, immutable',
    });
    fs.createReadStream(requestedPath).pipe(res);
  } catch {
    sendObsText(res, 404, 'Not found');
  }
}
async function handleObsBrowserSourceHttpRequest(req, res) {
  const requestUrl = new URL(req.url || '/', `http://127.0.0.1:${getConfiguredObsBrowserSourcePort()}`);
  const pathname = requestUrl.pathname;

  if (pathname === '/obs/health' && req.method === 'GET') {
    sendObsJson(res, 200, buildObsBrowserSourceStatus());
    return;
  }

  if (!isObsBrowserSourceEnabled()) {
    sendObsJson(res, 503, { error: 'OBS browser source is disabled.' });
    return;
  }

  if (pathname === '/obs/events' && req.method === 'GET') {
    if (!matchesObsBrowserSourceToken(requestUrl)) {
      sendObsJson(res, 401, { error: 'Unauthorized.' });
      return;
    }

    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
      'Access-Control-Allow-Origin': '*',
    });
    res.write(': connected\n\n');
    obsBrowserSourceClients.add(res);
    sendObsBrowserSourceBootstrapEvents(res);
    broadcastObsBrowserSourceStatus();

    req.on('close', () => {
      obsBrowserSourceClients.delete(res);
      broadcastObsBrowserSourceStatus();
    });
    return;
  }

  if (pathname === '/obs' && req.method === 'GET') {
    if (!matchesObsBrowserSourceToken(requestUrl)) {
      sendObsJson(res, 401, { error: 'Unauthorized.' });
      return;
    }

    if (isElectronDevRuntime()) {
      const devUrl = new URL('http://localhost:3000');
      devUrl.searchParams.set('obs', '1');
      devUrl.searchParams.set('token', requestUrl.searchParams.get('token') || '');
      devUrl.searchParams.set('obsPort', String(getConfiguredObsBrowserSourcePort()));
      res.writeHead(302, { Location: devUrl.toString() });
      res.end();
      return;
    }
  }

  await serveObsStaticFile(req, res, pathname);
}
async function startObsBrowserSourceServerIfNeeded() {
  if (!isObsBrowserSourceEnabled()) {
    return;
  }

  getObsBrowserSourceToken({ generateIfMissing: true });
  if (obsBrowserSourceServer) {
    return;
  }

  obsBrowserSourceServer = http.createServer((req, res) => {
    Promise.resolve(handleObsBrowserSourceHttpRequest(req, res)).catch((error) => {
      console.error('[OBS] Unhandled browser source request failure.', error);
      sendObsJson(res, 500, { error: 'Internal OBS browser source error.' });
    });
  });

  await new Promise((resolve, reject) => {
    obsBrowserSourceServer.once('error', reject);
    obsBrowserSourceServer.listen(getConfiguredObsBrowserSourcePort(), '127.0.0.1', () => {
      obsBrowserSourceServer.off('error', reject);
      resolve();
    });
  });

  console.log(`[OBS] Browser source listening on ${buildObsBrowserSourceUrl()}.`);
  broadcastObsBrowserSourceStatus();
}
async function stopObsBrowserSourceServer() {
  for (const client of Array.from(obsBrowserSourceClients)) {
    client.end();
  }
  obsBrowserSourceClients.clear();

  if (!obsBrowserSourceServer) {
    broadcastObsBrowserSourceStatus();
    return;
  }

  const server = obsBrowserSourceServer;
  obsBrowserSourceServer = null;
  await new Promise((resolve) => {
    server.close(() => resolve());
  });
  broadcastObsBrowserSourceStatus();
}
async function syncObsBrowserSourceServerState() {
  if (isObsBrowserSourceEnabled()) {
    await startObsBrowserSourceServerIfNeeded();
  } else {
    await stopObsBrowserSourceServer();
  }
  return buildObsBrowserSourceStatus();
}
function isElectronDevRuntime() {
  return process.env.ELECTRON_DEV === 'true' || process.env.NODE_ENV === 'development';
}
void syncObsBrowserSourceServerState();
return { getObsBrowserSourceStatus:buildObsBrowserSourceStatus,
setObsBrowserSourceEnabled:enabled=>{store.set(OBS_BROWSER_SOURCE_ENABLED_SETTING_KEY,Boolean(enabled));return syncObsBrowserSourceServerState();},
regenerateObsBrowserSourceToken:()=>{store.set(OBS_BROWSER_SOURCE_TOKEN_SETTING_KEY,crypto.randomBytes(32).toString('base64url'));broadcastObsBrowserSourceStatus();return buildObsBrowserSourceStatus();},
publishObsBrowserSourceConfig:config=>{latestObsBrowserSourceConfig=config||null;store.set('ANDROID_WALLPAPER_LAST_CONFIG',latestObsBrowserSourceConfig);if(config)broadcastObsBrowserSourceEvent('config',config);return true;},
publishObsBrowserSourceClock:clock=>{latestObsBrowserSourceClock=clock||null;if(clock)broadcastObsBrowserSourceEvent('clock',clock);return true;},
publishObsBrowserSourceAudio:audio=>{latestObsBrowserSourceAudio=audio||null;if(audio)broadcastObsBrowserSourceEvent('audio',audio);return true;}};};

// Generated from electron/main.cjs.
const AMLL_API_TIMEOUT_MS=5000;
function isAllowedLyricProxyHost(hostname) {
  return (
    hostname === 'qq.com' ||
    hostname.endsWith('.qq.com') ||
    hostname === 'y.gtimg.cn' ||
    hostname === 'kugou.com' ||
    hostname.endsWith('.kugou.com') ||
    hostname === 'kgimg.com' ||
    hostname.endsWith('.kgimg.com') ||
    hostname === 'api.amll.dev'
  );
}
function isAmllDbHost(hostname) {
  return hostname === 'api.amll.dev';
}
async function proxyLyricRequest(targetUrlStr, init = {}) {
  const targetUrl = new URL(targetUrlStr);
  const hostname = targetUrl.hostname;
  const isAmllDbRequest = isAmllDbHost(hostname);

  if (!isAllowedLyricProxyHost(hostname)) {
    throw new Error(`Forbidden lyric proxy host: ${hostname}`);
  }

  if (isAmllDbRequest) {
    console.log(`[AMLL Proxy] ${typeof init?.method === 'string' ? init.method : 'GET'} ${targetUrl.toString()}`);
  }

  const headers = new Headers(init?.headers || {});
  headers.delete('host');
  headers.delete('connection');
  headers.delete('content-length');
  headers.delete('origin');
  headers.delete('referer');

  const response = await fetch(targetUrl.toString(), {
    method: typeof init?.method === 'string' ? init.method : 'GET',
    headers,
    body: init?.body,
    ...(isAmllDbRequest ? { signal: AbortSignal.timeout(AMLL_API_TIMEOUT_MS) } : {}),
  });

  if (isAmllDbRequest) {
    console.log(`[AMLL Proxy] Response ${response.status} ${targetUrl.toString()}`);
  }

  const normalizedHeaders = {};
  for (const [key, value] of response.headers.entries()) {
    normalizedHeaders[key] = value;
  }

  return {
    ok: response.ok,
    status: response.status,
    statusText: response.statusText,
    headers: normalizedHeaders,
    bodyText: await response.text(),
  };
}
module.exports={fetchLyricProxy:proxyLyricRequest};

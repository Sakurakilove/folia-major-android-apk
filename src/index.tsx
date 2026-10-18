import { installAndroidPresentation } from './platform/android/installAndroidPresentation';
import { installAndroidBridge } from './platform/android/installAndroidBridge';
import { Buffer } from 'buffer';
import i18n from './i18n/config';
import { installGlobalVisualizerFrameRateLimiter } from './utils/frameRateLimiter';
import { installConsoleLogCapture } from './utils/consoleLogBuffer';
import { installDebugModule } from './services/debug/debugModule';
import { installMemorySampleFeed } from './services/debug/memorySamples';
// import { installCoverSizeAudit } from './services/debug/coverSizeSamples';
// @ts-ignore
globalThis.Buffer = Buffer;
// First, so the debug overlay's console tab has the startup lines too - they are where a failure
// to reach a library or restore a session shows up.
installConsoleLogCapture();
// Right after it, so the startup lines reach the runtime log file too and not only the in-memory
// buffer. Both no-op off Electron. See services/debug/debugModule.ts.
// Cover size audit, left wired but switched off: it answered whether the provider CDNs honour the
// size in a cover URL - they do - and that is not a question worth re-asking every session. The
// collector and its panel are still in the tree, and `?probe=coverSizeAudit` still reaches them.
// To bring the tab back, uncomment this line and the four sites in DevDebugOverlay.tsx. It was dev
// only even then: a packaged build has nothing to do with the answer, so it should not pay the
// observer or the rows it retains.
// if (import.meta.env.DEV) installCoverSizeAudit();
installAndroidPresentation();
installGlobalVisualizerFrameRateLimiter();

void installAndroidBridge().then(() => {
    installDebugModule();
    installMemorySampleFeed();
    return import('./bootstrap');
}).catch(error => {
    console.error('[AndroidRuntime] Startup failed', error);
    const splash = document.getElementById('app-splash');
    if (splash) {
        splash.replaceChildren();
        splash.classList.remove('is-hiding');
        splash.setAttribute('role', 'alert');
        Object.assign(splash.style, { padding: '24px', color: '#f4f4f5', background: '#09090b', flexDirection: 'column', gap: '20px', textAlign: 'center', overflowWrap: 'anywhere', overflow: 'auto' });
        const heading = document.createElement('h1');
        heading.textContent = i18n.t('ui.startupFailed');
        const detail = document.createElement('p');
        detail.textContent = String(error instanceof Error ? error.message : error);
        const retry = document.createElement('button');
        retry.type = 'button';
        retry.textContent = i18n.t('ui.startupRetry');
        Object.assign(retry.style, { minHeight: '48px', padding: '12px 24px', borderRadius: '12px', background: '#f4f4f5', color: '#09090b' });
        retry.onclick = () => window.location.reload();
        splash.append(heading, detail, retry);
    }
});

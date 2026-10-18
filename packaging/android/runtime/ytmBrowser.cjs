const fs = require('node:fs/promises');

// Preserve the upstream login state machine, using a separate native browser process instead of a desktop executable.
module.exports = ({ events, youtubeCookies = require('./electron/ytm/browserSignIn.cjs').youtubeCookies }) => {
    let cookies = [], userAgent = '', running = null;
    return {
        userAgent: () => userAgent,
        findBrowser: () => 'android-gecko',
        openSignIn: (_browser, profile) => {
            cookies = []; userAgent = '';
            let cancelled = false;
            const closed = events.native('ytmBrowserOpen', profile).then(result => {
                if (cancelled) { cookies = []; return 'at-once'; }
                cookies = result.outcome === 'closed' || result.outcome === 'stopped' ? youtubeCookies(result.cookies || []) : []; userAgent = String(result.userAgent || '');
                if (!userAgent) throw new Error('The Android sign-in browser did not report its user agent');
                return result.outcome;
            }).catch(error => {
                cookies = [];
                console.warn('[Ytm] Android sign-in browser could not complete', error);
                return 'at-once';
            });
            running = closed;
            void closed.finally(() => { if (running === closed) running = null; }).catch(() => {});
            return { closed, stop: () => { cancelled = true; cookies = []; void events.native('ytmBrowserStop').catch(error => console.warn('[Ytm] Cannot close sign-in browser', error)); } };
        },
        readCookies: async () => { const result = cookies; cookies = []; return result; },
        endLeftBrowsers: async () => { if (running) { await events.native('ytmBrowserStop'); await running; } return true; },
        removeProfile: async profile => { cookies = []; try { await fs.rm(profile, { recursive: true, force: true }); return true; } catch { return false; } },
    };
};

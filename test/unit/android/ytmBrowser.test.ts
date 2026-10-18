import { afterEach, describe, expect, it, vi } from 'vitest';
import { createRequire } from 'node:module';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
const require = createRequire(import.meta.url);
const { youtubeCookies } = require('../../../electron/ytm/browserSignIn.cjs');
const { createYtmWebSignIn } = require('../../../electron/ytm/webSignIn.cjs');
const createBrowser = require('../../../packaging/android/runtime/ytmBrowser.cjs');
const temporary: string[] = [];
afterEach(() => { for (const directory of temporary.splice(0)) rmSync(directory, { recursive: true, force: true }); });

// Check the Android browser against the original account-validation and cancellation state machine.
describe('Android YouTube browser handoff', () => {
    it('keeps only YouTube cookies, validates the account, uses the real browser name and consumes credentials once', async () => {
        const directory = mkdtempSync(path.join(tmpdir(), 'folia-browser-')); temporary.push(directory);
        let finish!: (value: unknown) => void;
        const browser = createBrowser({ youtubeCookies, events: { native: (method: string) => method === 'ytmBrowserOpen'
            ? new Promise(resolve => { finish = resolve; }) : Promise.resolve(true) } });
        const accountOf = vi.fn(async () => ({ id: 'account', nickname: 'Listener' }));
        const keep = vi.fn();
        const login = createYtmWebSignIn({ browser, profileDir: () => directory, browserName: browser.userAgent, accountOf, keep, log: () => {}, warn: () => {} });
        await login.start();
        expect(login.check().state).toBe('waiting');
        finish({ outcome: 'closed', userAgent: 'Firefox Android browser', cookies: [
            { name: 'SAPISID', value: 'dummy-youtube-secret', domain: '.youtube.com', path: '/' },
            { name: 'other', value: 'excluded', domain: '.example.com', path: '/' },
        ] });
        await vi.waitFor(() => expect(login.check().state).toBe('confirmed'));
        expect(accountOf).toHaveBeenCalledWith({ cookie: 'SAPISID=dummy-youtube-secret', userAgent: 'Firefox Android browser' });
        expect(keep).toHaveBeenCalledTimes(1);
        expect(await browser.readCookies()).toEqual([]);
    });
    it('does not adopt credentials after cancellation even when the browser later reports a completed sign-in', async () => {
        const directory = mkdtempSync(path.join(tmpdir(), 'folia-browser-cancel-')); temporary.push(directory);
        let finish!: (value: unknown) => void;
        const browser = createBrowser({ youtubeCookies, events: { native: (method: string) => method === 'ytmBrowserOpen'
            ? new Promise(resolve => { finish = resolve; }) : Promise.resolve(true) } });
        const keep = vi.fn(), accountOf = vi.fn();
        const login = createYtmWebSignIn({ browser, profileDir: () => directory, browserName: browser.userAgent, accountOf, keep, log: () => {}, warn: () => {} });
        await login.start(); login.cancel();
        finish({ outcome: 'closed', userAgent: 'Firefox Android browser', cookies: [{ name: 'SAPISID', value: 'cancelled-dummy-secret', domain: '.youtube.com', path: '/' }] });
        await login.quit();
        expect(accountOf).not.toHaveBeenCalled(); expect(keep).not.toHaveBeenCalled();
        expect(await browser.readCookies()).toEqual([]);
    });
});

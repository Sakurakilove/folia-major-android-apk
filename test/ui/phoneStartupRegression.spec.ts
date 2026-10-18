import { test, expect } from '@playwright/test';
import { installBaseState, mockNeteaseApi } from './helpers/appFixtures';

// Exercise the real first render with Android phone branches; no emulator or account is required.
test('phone library mounts after its splash without a render exception', async ({ page }) => {
    await page.setViewportSize({ width: 412, height: 860 });
    const failures: string[] = [];
    page.on('pageerror', error => { failures.push(error.stack ?? error.message); console.error('PHONE_STARTUP_ERROR', error.stack ?? error.message); });
    page.on('console', message => { if (message.type() === 'error') console.error('PHONE_CONSOLE_ERROR', message.text()); });
    await installBaseState(page, { neteaseMode: 'guest', preserveNativeMediaQueries: true });
    await page.addInitScript(() => {
        Object.defineProperty(window, 'electron', { configurable: true, value: { ...window.electron, platform: 'android' } });
        localStorage.setItem('library_suite', 'bravais');
        localStorage.setItem('visualizer_frame_rate', '60');
        document.addEventListener('DOMContentLoaded', () => { document.documentElement.dataset.foliaAndroid = 'true'; });
    });
    await mockNeteaseApi(page, 'guest');
    await page.goto('/');
    await expect(page.locator('[data-folia-app-shell]')).toBeVisible({ timeout: 45000 });
    await expect(page.locator('[data-library-home="bravais"]')).toHaveCount(1);
    await page.evaluate(async () => {
        // @ts-expect-error Browser imports the real Vite module to display a local, offline fixture.
        const { usePlaybackStore } = await import('/src/stores/usePlaybackStore.ts');
        usePlaybackStore.setState({ currentSong: { id: 74001, name: 'Phone song title', artists: [{ id: 1, name: 'Phone artist' }],
            album: { id: 1, name: 'Phone album', picUrl: '' }, durationMs: 180000 }, duration: 180 });
    });
    const transport = page.locator('[data-folia-phone-transport]');
    await expect(transport).toBeVisible();
    await expect(transport.locator('[data-folia-track-title]')).toHaveText('Phone song title');
    await expect(transport.locator('[data-folia-track-artist]')).toHaveText('Phone artist');
    const titleBox = await transport.locator('[data-folia-track-title]').boundingBox();
    const panelBox = await page.locator('[data-folia-mobile-player-panel]').boundingBox();
    expect(titleBox!.width).toBeGreaterThan(90);
    expect(panelBox!.height).toBeLessThan(120);
    expect(failures).toEqual([]);
});

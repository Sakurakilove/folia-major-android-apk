import { expect, test } from '@playwright/test';
import { rolldown } from 'rolldown';
import path from 'node:path';

// Browser-side gesture progress/cancellation and portal focus dispatch, independent of the native gesture source.
let source: string;
let dragSource: string;
test.beforeAll(async () => {
    const bundle = await rolldown({ input: path.resolve('src/platform/android/installAndroidBack.ts') });
    try {
        const result = await bundle.generate({ format: 'iife', name: 'FoliaBack' });
        source = (result.output[0] as { code: string }).code;
    } finally { await bundle.close(); }
    const drag = await rolldown({ input: path.resolve('src/platform/android/installAndroidWindowDrag.ts') });
    try {
        const result = await drag.generate({ format: 'iife', name: 'FoliaDrag' });
        dragSource = (result.output[0] as { code: string }).code;
    } finally { await drag.close(); }
});
test('cancel restores transforms and commit closes the focused combobox before its settings dialog', async ({ page }) => {
    await page.route('http://folia.test/**', route => route.fulfill({ body: '<div id="root"></div>' }));
    await page.goto('http://folia.test/');
    await page.addScriptTag({ content: source });
    await page.evaluate(() => {
        const probe = window as unknown as { back: (event: unknown) => void; enabled: boolean[];
            FoliaBack: { installAndroidBack: (runtime: unknown) => void } };
        probe.enabled = [];
        probe.FoliaBack.installAndroidBack({
            backState: async ({ enabled }: { enabled: boolean }) => { probe.enabled.push(enabled); },
            addListener: async (_name: string, callback: typeof probe.back) => { probe.back = callback; return { remove() {} }; },
        });
    });
    expect(await page.evaluate(() => (window as any).enabled.at(-1))).toBe(false);
    await page.evaluate(() => {
        document.getElementById('root')!.innerHTML = '<div role="dialog" id="settings"><button id="trigger" aria-expanded="true" aria-controls="choices">Choose</button></div><div role="listbox" id="choices" style="translate: 2px; scale: 0.93">A</div>';
        const trigger = document.getElementById('trigger')!;
        trigger.addEventListener('keydown', event => {
            if (event.key !== 'Escape') return;
            event.stopPropagation(); document.getElementById('choices')!.remove(); trigger.setAttribute('aria-expanded', 'false');
        });
        window.addEventListener('keydown', () => document.getElementById('settings')!.remove());
        trigger.focus();
        (window as any).back({ phase: 'start', progress: 0 });
        (window as any).back({ phase: 'progress', progress: 0.5, edge: 0 });
    });
    await expect.poll(() => page.locator('#choices').evaluate(element => (element as HTMLElement).style.scale)).toBe('0.98');
    await page.evaluate(() => (window as any).back({ phase: 'cancel', progress: 0 }));
    expect(await page.locator('#choices').evaluate(element => (element as HTMLElement).style.translate)).toBe('2px');
    expect(await page.locator('#choices').evaluate(element => (element as HTMLElement).style.scale)).toBe('0.93');
    await page.evaluate(() => (window as any).back({ phase: 'commit', progress: 1 }));
    await expect(page.locator('#choices')).toHaveCount(0);
    await expect(page.locator('#settings')).toHaveCount(1);
});

test('floating-window drag excludes nested button icons and uses the existing title region', async ({ page }) => {
    await page.setContent('<div id="title" style="--folia-app-region:drag; width:400px; height:100px"><span id="label">Move window</span><button style="margin-left:50px"><span id="icon">Play</span></button></div>');
    await page.addScriptTag({ content: dragSource });
    await page.evaluate(() => {
        (window as any).dragCalls=[];
        (window as any).FoliaDrag.installAndroidWindowDrag({ windowDrag: async (event: unknown) => {
            (window as any).dragCalls.push(event); return { active: true };
        } });
    });
    await page.locator('#icon').click();
    expect(await page.evaluate(() => (window as any).dragCalls.length)).toBe(0);
    const label = await page.locator('#label').boundingBox();
    if (!label) throw new Error('Missing title label');
    await page.mouse.move(label.x+5,label.y+5);
    await page.mouse.down();
    await expect.poll(() => page.evaluate(() => (window as any).dragCalls.length)).toBe(1);
    await page.mouse.move(label.x+70,label.y+30,{ steps: 3 });
    await expect.poll(() => page.evaluate(() => (window as any).dragCalls.some((event: any) => event.phase==='move'))).toBe(true);
    await page.mouse.up();
    await expect.poll(() => page.evaluate(() => (window as any).dragCalls.at(-1).phase)).toBe('end');
});

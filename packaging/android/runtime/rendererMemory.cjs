const { randomUUID } = require('node:crypto');

// Identify this WebView's actual renderer PID with its own trace marker, then read Chromium memory-infra dumps.
module.exports = async client => {
    const marker = 'folia-memory-' + randomUUID();
    const entries = [];
    let finished, started = false, timer;
    const complete = new Promise(resolve => { finished = resolve; });
    const detach = client.onEvent((method, params) => {
        if (method === 'Tracing.dataCollected') entries.push(...(params.value || []));
        if (method === 'Tracing.tracingComplete') finished(true);
    });
    try {
        await client.send('Tracing.start', { categories: 'devtools.timeline,disabled-by-default-memory-infra', transferMode: 'ReportEvents' });
        started = true;
        await client.send('Runtime.evaluate', { expression: 'console.timeStamp(' + JSON.stringify(marker) + ')' });
        const result = await client.send('Tracing.requestMemoryDump', { levelOfDetail: 'light', deterministic: false });
        await client.send('Tracing.end'); started = false;
        const timeout = new Promise(resolve => { timer = setTimeout(() => resolve(false),5000); });
        if (!await Promise.race([complete,timeout]) || result.success === false) return null;
        const identity = entries.find(entry => entry.name === 'TimeStamp' && entry.args?.data?.message === marker);
        if (!identity || !Number.isInteger(identity.pid) || identity.pid <= 0) return null;
        const dump = entries.findLast(entry => entry.pid === identity.pid && entry.args?.dumps?.process_totals);
        if (!dump) return null;
        const totals = dump.args.dumps.process_totals, allocators = dump.args.dumps.allocators || {};
        const size = value => {
            if (typeof value !== 'string' || !/^[\da-f]+$/i.test(value)) return undefined;
            const bytes = Number.parseInt(value,16);
            return Number.isSafeInteger(bytes) && bytes >= 0 ? bytes / 1024 : undefined;
        };
        const report = { pid: identity.pid, residentKB: size(totals.resident_set_bytes),
            privateKB: size(totals.private_footprint_bytes),
            blinkAllocatedKB: size((allocators['blink_gc/allocated_objects'] || allocators.blink_gc)?.attrs?.size?.value) };
        if (report.residentKB === undefined && report.privateKB === undefined && report.blinkAllocatedKB === undefined) return null;
        return report;
    } catch (error) {
        console.warn('[AndroidMemory] WebView memory-infra inspection unavailable',error);
        return null;
    } finally {
        clearTimeout(timer);
        if (started) await client.send('Tracing.end').catch(() => {});
        detach();
    }
};

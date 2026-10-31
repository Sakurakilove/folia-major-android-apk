const fs = require('node:fs');
const os = require('node:os');
const v8 = require('node:v8');

// Report the Android Node process from /proc and V8; absent OS fields remain absent.
module.exports = () => {
    const fields = file => {
        try { return Object.fromEntries([...fs.readFileSync(file, 'utf8').matchAll(/^([A-Za-z_]+):\s+(\d+)/gm)].map(match => [match[1], Number(match[2])])); }
        catch { return {}; }
    };
    process.getHeapStatistics ??= () => {
        const heap = v8.getHeapStatistics();
        return { usedHeapSize: heap.used_heap_size / 1024, totalHeapSize: heap.total_heap_size / 1024, totalHeapSizeExecutable: heap.total_heap_size_executable / 1024,
            totalPhysicalSize: heap.total_physical_size / 1024, totalAvailableSize: heap.total_available_size / 1024, heapSizeLimit: heap.heap_size_limit / 1024,
            mallocedMemory: heap.malloced_memory / 1024, peakMallocedMemory: heap.peak_malloced_memory / 1024 };
    };
    process.getSystemMemoryInfo ??= () => {
        const memory = fields('/proc/meminfo');
        return { total: memory.MemTotal ?? Math.round(os.totalmem() / 1024), free: memory.MemFree ?? Math.round(os.freemem() / 1024),
            swapTotal: memory.SwapTotal, swapFree: memory.SwapFree };
    };
    process.getProcessMemoryInfo ??= async () => {
        let memory;
        try { memory = Object.fromEntries([...(await fs.promises.readFile('/proc/self/smaps_rollup', 'utf8')).matchAll(/^([A-Za-z_]+):\s+(\d+)/gm)].map(match => [match[1], Number(match[2])])); }
        catch { memory = {}; }
        if (memory.Private_Clean === undefined || memory.Private_Dirty === undefined) throw new Error('Android does not expose process private memory');
        return { private: memory.Private_Clean + memory.Private_Dirty + (memory.Private_Hugetlb || 0),
            shared: (memory.Shared_Clean || 0) + (memory.Shared_Dirty || 0) + (memory.Shared_Hugetlb || 0), residentSet: memory.Rss };
    };
    let previousCPU = process.cpuUsage(), previousTime = process.hrtime.bigint();
    return () => {
        const status = fields('/proc/self/status'), currentCPU = process.cpuUsage(), currentTime = process.hrtime.bigint();
        const elapsed = Number(currentTime - previousTime) / 1000;
        const cpu = elapsed > 0 ? ((currentCPU.user - previousCPU.user + currentCPU.system - previousCPU.system) / elapsed) * 100 : 0;
        previousCPU = currentCPU; previousTime = currentTime;
        return [{ pid: process.pid, type: 'Utility', name: 'Android Node backend', creationTime: Date.now() - process.uptime() * 1000,
            memory: { workingSetSize: status.VmRSS ?? Math.round(process.memoryUsage().rss / 1024), peakWorkingSetSize: status.VmHWM },
            cpu: { percentCPUUsage: cpu, cumulativeCPUUsage: (currentCPU.user + currentCPU.system) / 1e6 } }];
    };
};

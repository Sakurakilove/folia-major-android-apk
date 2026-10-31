import type { LyricData } from '../../types';

// Index an immutable lyric snapshot while retaining the latest-active-line overlap semantics.
export const createActiveLineLookup = (lines: LyricData['lines']): ((time: number) => number) => {
    const starts: number[] = [];
    const ends: number[] = [];
    const prefixEnds: number[] = [];
    let ordered = true;
    let furthest = -Infinity;
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        const start = line?.startTime;
        const end = line?.renderHints?.renderEndTime ?? line?.endTime;
        if (!Number.isFinite(start) || !Number.isFinite(end) || (index > 0 && start < starts[index - 1])) ordered = false;
        starts.push(start);
        ends.push(end);
        furthest = Math.max(furthest, end);
        prefixEnds.push(furthest);
    }
    return time => {
        if (!ordered || !Number.isFinite(time)) {
            for (let index = lines.length - 1; index >= 0; index--) {
                const line = lines[index];
                if (line && !(time < line.startTime) && time <= (line.renderHints?.renderEndTime ?? line.endTime)) return index;
            }
            return -1;
        }
        let low = 0;
        let high = starts.length;
        while (low < high) {
            const middle = (low + high) >>> 1;
            if (starts[middle] <= time) low = middle + 1;
            else high = middle;
        }
        for (let index = low - 1; index >= 0 && prefixEnds[index] >= time; index--) {
            if (ends[index] >= time) return index;
        }
        return -1;
    };
};

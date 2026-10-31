import { useCallback, useLayoutEffect, useRef } from 'react';
import type { MotionValue } from 'framer-motion';

// One clock subscription per lyric line; words write only changed paint properties without React frames.
export type MonetWordPainter = (time: number) => void;
export type RegisterMonetWord = (paint: MonetWordPainter) => () => void;

export const useMonetWordClock = (clock: MotionValue<number>): RegisterMonetWord => {
    const painters = useRef(new Set<MonetWordPainter>());
    const register = useCallback((paint: MonetWordPainter) => {
        painters.current.add(paint);
        paint(clock.get());
        return () => { painters.current.delete(paint); };
    }, [clock]);
    useLayoutEffect(() => clock.on('change', time => {
        for (const paint of painters.current) paint(time);
    }), [clock]);
    return register;
};

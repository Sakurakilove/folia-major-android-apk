import React, { useLayoutEffect, useMemo, useRef } from 'react';
import type { MotionValue } from 'framer-motion';
import { useMonetWordClock, type RegisterMonetWord } from './useMonetWordClock';
import { type GraphemeTiming } from '../../../utils/lyrics/graphemeTiming';
import { getLineRenderEndTime } from '../../../utils/lyrics/renderHints';
import { colorWithAlpha, mixColors } from '../colorMix';
import { resolveMonetFillWidth, resolveMonetGlow } from './monetLyricMotion';
import { buildWordColorRangesFromMatchers, resolveTokenColorMap, type WordColorMatcher } from '../wordColoring';
import { buildMonetDisplayTokens, measureMonetGraphemeOffsets, resolveMonetSweepEdgeSoftness, resolveMonetSweepEnd, resolveMonetWordStatus, type MonetLineStatus } from './monetLyricsModel';
import type { PositionedMonetLineEntry } from './monetRailLayout';

// src/components/visualizer/monet/MonetRailTokens.tsx
// 行内的逐词渲染：按时间着色的 token 与当前行的扫字遮罩 / 填充 / glow。


export const MonetTimedTokenSpan: React.FC<{
    entry: PositionedMonetLineEntry;
    currentTime: MotionValue<number>;
    accentColor: string;
    fontPx: number;
    fontStack: string;
    fontsEpoch: number;
    wordColorMatchers: WordColorMatcher[];
    isChorus?: boolean;
    chorusAccentColor?: string;
    audioPower?: MotionValue<number>;
    renderStaticPassed?: boolean;
}> = ({ entry, currentTime, accentColor, fontPx, fontStack, fontsEpoch, wordColorMatchers, isChorus, chorusAccentColor, audioPower, renderStaticPassed = false }) => {
    const registerWord = useMonetWordClock(currentTime);
    const lineRenderEndTime = useMemo(() => getLineRenderEndTime(entry.line), [entry.line]);
    const tokens = useMemo(() => buildMonetDisplayTokens(entry.line), [entry.line]);
    const wordColorRanges = useMemo(
        () => buildWordColorRangesFromMatchers(entry.line.fullText, wordColorMatchers),
        [entry.line.fullText, wordColorMatchers],
    );
    const tokenColors = useMemo(
        () => resolveTokenColorMap(tokens, wordColorRanges),
        [tokens, wordColorRanges],
    );
    const fontSpec = useMemo(
        () => `${entry.tone.fontWeight} ${fontPx}px ${fontStack}`,
        [entry.tone.fontWeight, fontPx, fontStack],
    );

    const resolvedAccentColor = isChorus && chorusAccentColor
        ? mixColors(accentColor, chorusAccentColor, 0.48)
        : accentColor;

    return (
        <span className="block w-full min-w-0 max-w-full whitespace-pre-wrap break-words">
            {tokens.map(token => (
                renderStaticPassed ? (
                    <span
                        key={token.key}
                        style={{
                            color: token.timed
                                ? tokenColors.get(token.key) ?? resolvedAccentColor
                                : entry.tone.baseColor,
                        }}
                    >
                        {token.text}
                    </span>
                ) : token.timed && token.startTime !== null && token.endTime !== null ? (
                    <MonetWordSweep
                        key={token.key}
                        text={token.text}
                        startTime={token.startTime}
                        endTime={token.endTime}
                        graphemeTimings={token.graphemeTimings}
                        lineRenderEndTime={lineRenderEndTime}
                        registerWord={registerWord}
                        lineStatus={entry.status}
                        wordColor={tokenColors.get(token.key) ?? resolvedAccentColor}
                        baseColor={entry.tone.baseColor}
                        fontPx={fontPx}
                        fontSpec={fontSpec}
                        fontsEpoch={fontsEpoch}
                        isChorus={isChorus}
                        audioPower={audioPower}
                    />
                ) : (
                    <span key={token.key} style={{ color: entry.tone.baseColor }}>
                        {token.text}
                    </span>
                )
            ))}
        </span>
    );
};

const MonetWordSweep: React.FC<{
    text: string;
    startTime: number;
    endTime: number;
    graphemeTimings: GraphemeTiming[];
    lineRenderEndTime: number;
    registerWord: RegisterMonetWord;
    lineStatus: MonetLineStatus;
    wordColor: string;
    baseColor: string;
    fontPx: number;
    fontSpec: string;
    /** Bumped when web fonts load; measured offsets are stale until then. */
    fontsEpoch: number;
    isChorus?: boolean;
    audioPower?: MotionValue<number>;
}> = ({
    text,
    startTime,
    endTime,
    graphemeTimings,
    lineRenderEndTime,
    registerWord,
    lineStatus,
    wordColor,
    baseColor,
    fontPx,
    fontSpec,
    fontsEpoch,
    isChorus,
    audioPower,
}) => {
        const isLineActive = lineStatus === 'active';
        const canRenderGlow = lineStatus === 'active' || lineStatus === 'passed';
        const graphemeOffsets = useMemo(
            () => measureMonetGraphemeOffsets(text, fontPx, fontSpec),
            // eslint-disable-next-line react-hooks/exhaustive-deps -- fontsEpoch re-measures once the real face loads
            [text, fontPx, fontSpec, fontsEpoch],
        );

        const baseRef = useRef<HTMLSpanElement>(null);
        const maskRef = useRef<HTMLSpanElement>(null);
        const fillRef = useRef<HTMLSpanElement>(null);
        const paint = useMemo(() => {
            let previousTime: number | undefined;
            let previousSweepTime: number | undefined;
            const written = new WeakMap<HTMLElement, Partial<Record<keyof CSSStyleDeclaration, string>>>();
            const tail = Math.max(lineRenderEndTime, endTime + 1.05, startTime + Math.max(0.001, endTime - startTime) * 1.18);
            const edgeSoftness = resolveMonetSweepEdgeSoftness(fontPx);
            const fullWidth = graphemeOffsets[graphemeOffsets.length - 1] ?? 0;
            const radiusOne = Math.round(fontPx * (isChorus ? 0.45 : 0.28));
            const radiusTwo = Math.round(fontPx * (isChorus ? 0.90 : 0.65));
            const maxAlpha = isChorus ? 1.0 : 0.88;
            const write = (element: HTMLElement, key: 'color' | 'textShadow' | 'maskImage' | 'webkitMaskImage' | 'backgroundImage', value: string) => {
                const values = written.get(element) ?? {};
                if (values[key] === value) return;
                element.style[key] = value;
                values[key] = value;
                written.set(element, values);
            };
            return (time: number) => {
                const base = baseRef.current;
                if (!base) return;
                // Saturated words are static, including across seeks back into their live interval.
                const stamp = isLineActive || canRenderGlow ? Math.max(startTime, Math.min(time, tail)) : 0;
                if (stamp === previousTime) return;
                previousTime = stamp;
                const status = isLineActive ? resolveMonetWordStatus(time, startTime, endTime) : lineStatus;
                write(base, 'color', (isLineActive && status === 'passed') || lineStatus === 'passed' ? wordColor : baseColor);
                let shadow = 'none';
                if (canRenderGlow && time > startTime) {
                    const intensity = resolveMonetGlow(time, startTime, endTime, lineRenderEndTime);
                    if (intensity > 0) {
                        const color = mixColors(baseColor, wordColor, intensity, intensity * maxAlpha);
                        shadow = `0 0 ${radiusOne}px ${color}, 0 0 ${radiusTwo}px ${color}`;
                    }
                }
                write(base, 'textShadow', shadow);
                if (!isLineActive || !maskRef.current || !fillRef.current) return;
                const sweepStamp = Math.max(startTime, Math.min(time, endTime));
                if (previousSweepTime === sweepStamp) return;
                previousSweepTime = sweepStamp;
                const width = resolveMonetFillWidth(time, startTime, endTime, graphemeOffsets, graphemeTimings);
                const sweepEnd = resolveMonetSweepEnd(width, fullWidth, edgeSoftness);
                const solidEnd = Math.max(sweepEnd - edgeSoftness, 0);
                const featherStart = Math.max(sweepEnd - edgeSoftness * 0.55, 0);
                const featherEnd = Math.max(sweepEnd, 0);
                const mask = `linear-gradient(90deg, rgba(0, 0, 0, 1) 0px, rgba(0, 0, 0, 1) ${solidEnd}px, rgba(0, 0, 0, 0.92) ${featherStart}px, rgba(0, 0, 0, 0) ${featherEnd}px, rgba(0, 0, 0, 0) 100%)`;
                write(maskRef.current, 'maskImage', mask);
                write(maskRef.current, 'webkitMaskImage', mask);
                const progress = time <= startTime ? 0 : time >= endTime ? 1 : (time - startTime) / Math.max(0.001, endTime - startTime);
                const color = mixColors(baseColor, wordColor, Math.min(progress, 1));
                write(fillRef.current, 'backgroundImage', `linear-gradient(90deg, ${color} 0%, ${colorWithAlpha(color, 0.92)} 68%, ${colorWithAlpha(color, 0.72)} 100%)`);
            };
        }, [baseColor, canRenderGlow, endTime, fontPx, graphemeOffsets, graphemeTimings, isChorus, isLineActive, lineRenderEndTime, lineStatus, startTime, wordColor]);
        useLayoutEffect(() => registerWord(paint), [paint, registerWord]);

        // Glyphs with deep descenders (g, j, p, y, and many CJK forms) sit below the line box
        // whenever the font's em box is taller than `line-height`, which drives half-leading
        // negative. `background-clip: text` paints no background outside the fill box and the mask
        // clips at the overlay's border box, so the sweep used to stop mid-glyph — more visibly the
        // larger the font. Grow both boxes, then pull the text back so its position is unchanged.
        const sweepOverflowPx = Math.round(fontPx * 0.5);

        return (
            <span className="relative inline-block whitespace-pre-wrap break-words">
                <span ref={baseRef} style={{ color: baseColor }}>
                    {text}
                </span>
                {isLineActive ? (
                    <span
                        ref={maskRef}
                        aria-hidden
                        className="pointer-events-none absolute left-0 right-0 block whitespace-pre-wrap break-words"
                        style={{
                            top: -sweepOverflowPx,
                            bottom: -sweepOverflowPx,
                            paddingTop: sweepOverflowPx,
                            paddingBottom: sweepOverflowPx,
                            boxSizing: 'border-box',
                            WebkitMaskSize: '100% 100%',
                            maskSize: '100% 100%',
                            WebkitMaskRepeat: 'no-repeat',
                            maskRepeat: 'no-repeat',
                            textShadow: 'none',
                        }}
                    >
                        <span
                            ref={fillRef}
                            className="block whitespace-pre-wrap break-words"
                            style={{
                                marginTop: -sweepOverflowPx,
                                paddingTop: sweepOverflowPx,
                                paddingBottom: sweepOverflowPx,
                                color: 'transparent',
                                WebkitTextFillColor: 'transparent',
                                WebkitBackgroundClip: 'text',
                                backgroundClip: 'text',
                            }}
                        >
                            {text}
                        </span>
                    </span>
                ) : null}
            </span>
        );
    };

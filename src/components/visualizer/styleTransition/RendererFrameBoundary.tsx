import React, { createContext, useLayoutEffect, useRef, useState } from 'react';

// Aggregate the actual style/background first frames before a host releases its previous surface.
interface FrameGroup {
    claim(token: object, kind: 'style' | 'background'): () => void;
    drawn(token: object): void;
}
export const RendererFrameContext = createContext<FrameGroup | null>(null);
export const RendererFrameBoundary: React.FC<React.PropsWithChildren<{
    onReady: () => void;
    present: () => Promise<void>;
}>> = ({ children, onReady, present }) => {
    const callbacks = useRef({ onReady, present });
    callbacks.current = { onReady, present };
    const [group] = useState(() => {
        const members = new Map<object, { kind: string; drawn: boolean }>();
        const early = new WeakSet<object>(), retired = new WeakSet<object>();
        let active = false, pending = false, fired = false, frame = 0, epoch = 0;
        const ready = () => [...members.values()].some(member => member.kind === 'style')
            && [...members.values()].every(member => member.drawn);
        const schedule = () => {
            if (!active || fired || pending || frame) return;
            frame = requestAnimationFrame(() => {
                frame = 0;
                if (!active || fired || !ready()) return;
                const version = epoch;
                pending = true;
                void callbacks.current.present().then(() => {
                    pending = false;
                    if (!active || fired) return;
                    if (epoch !== version || !ready()) { schedule(); return; }
                    fired = true;
                    callbacks.current.onReady();
                }).catch(error => {
                    pending = false;
                    if (active) console.warn('[RendererFrame] Presentable-frame confirmation failed:', error);
                });
            });
        };
        return {
            mount() { active = true; schedule(); return () => { active = false; cancelAnimationFrame(frame); frame = 0; }; },
            claim(token: object, kind: 'style' | 'background') {
                retired.delete(token);
                members.set(token, { kind, drawn: early.has(token) }); epoch++; schedule();
                return () => { retired.add(token); members.delete(token); epoch++; schedule(); };
            },
            drawn(token: object) {
                if (retired.has(token)) return;
                early.add(token);
                const member = members.get(token);
                if (member && !member.drawn) { member.drawn = true; epoch++; }
                schedule();
            },
        };
    });
    useLayoutEffect(() => group.mount(), [group]);
    return <RendererFrameContext.Provider value={group}>{children}</RendererFrameContext.Provider>;
};

import type { CSSProperties } from 'react';

// Shared live-backdrop material; no captured cover or second rendering surface is involved.
export const liquidGlassTokens = (light: boolean): CSSProperties => ({
    '--folia-glass-window-tint': light ? 'rgba(245, 250, 255, 0.68)' : 'rgba(15, 20, 28, 0.72)',
    '--folia-glass-tint': light ? 'rgba(245, 250, 255, 0.22)' : 'rgba(15, 20, 28, 0.28)',
    '--folia-glass-rim': light ? 'rgba(255, 255, 255, 0.64)' : 'rgba(255, 255, 255, 0.22)',
    '--folia-glass-glint': light ? 'rgba(255, 255, 255, 0.32)' : 'rgba(255, 255, 255, 0.12)',
    '--folia-glass-shadow': light ? 'rgba(20, 38, 60, 0.16)' : 'rgba(0, 0, 0, 0.32)',
} as CSSProperties);

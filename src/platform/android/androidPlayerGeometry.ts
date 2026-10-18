import { motionValue } from 'framer-motion';

// Bottom exclusion measured from the real phone player rectangle, shared without React frame updates.
export const androidPlayerClearance = motionValue(0);
export const publishAndroidPlayerClearance = (value: number): void => {
    const safe = Math.max(0, Math.ceil(value));
    if (androidPlayerClearance.get() === safe) return;
    androidPlayerClearance.set(safe);
    document.documentElement.style.setProperty('--folia-player-clearance', `${safe}px`);
};

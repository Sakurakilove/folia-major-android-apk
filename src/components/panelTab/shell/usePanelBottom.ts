import { useTransform } from 'framer-motion';
import { usePhoneLayout } from '../../../hooks/usePhoneLayout';
import { usePlayerBottomBarBottomPx } from '../../../hooks/usePlayerBottomBarBottomPx';
import { androidPlayerClearance } from '../../../platform/android/androidPlayerGeometry';

// Both the panel and its handle clear the real phone transport, including a dragged bar.
export const usePanelBottom = () => {
    const phone = usePhoneLayout();
    const baseline = usePlayerBottomBarBottomPx();
    return useTransform([baseline, androidPlayerClearance], ([base, clearance]) => phone
        ? Math.max(base as number, clearance as number)
        : base as number);
};

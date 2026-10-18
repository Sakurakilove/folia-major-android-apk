import { useMediaQuery } from './useMediaQuery';
import { runsOnAndroid } from '../utils/platform';

// Subscribe only to a breakpoint, never to pointer positions or animation frames.
export const usePhoneLayout = (): boolean => {
    const narrow = useMediaQuery('(max-width: 767px)');
    return runsOnAndroid() && narrow;
};

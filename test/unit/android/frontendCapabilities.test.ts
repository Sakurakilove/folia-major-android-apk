import { afterEach, describe, expect, it, vi } from 'vitest';
import { runsOnAndroid, supportsVoiceInputPause } from '../../../src/utils/platform';
import { matchesCommandPlatform } from '../../../src/components/command-palette/availability';

// Android must expose its implemented settings without pretending to be Windows and enabling unrelated OS controls.
afterEach(() => vi.unstubAllGlobals());
describe('Android frontend platform capabilities', () => {
    it('offers native voice-input and Android/electron commands through the actual Android bridge', () => {
        vi.stubGlobal('navigator',{userAgent:'Mozilla/5.0 (Linux; Android 17)'});
        vi.stubGlobal('window',{electron:{platform:'android'}});
        expect(runsOnAndroid()).toBe(true);
        expect(supportsVoiceInputPause()).toBe(true);
        expect(matchesCommandPlatform(['android'])).toBe(true);
        expect(matchesCommandPlatform(['electron'])).toBe(true);
        expect(matchesCommandPlatform(['win'])).toBe(false);
        expect(matchesCommandPlatform(['mac'])).toBe(false);
    });
    it('does not offer a native Android capability to a normal mobile browser', () => {
        vi.stubGlobal('navigator',{userAgent:'Mozilla/5.0 (Linux; Android 17)'});
        vi.stubGlobal('window',{});
        expect(supportsVoiceInputPause()).toBe(false);
        expect(matchesCommandPlatform(['android'])).toBe(false);
        expect(matchesCommandPlatform(['web'])).toBe(true);
    });
});

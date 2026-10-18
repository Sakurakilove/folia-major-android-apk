import { describe, expect, it } from 'vitest';
import { hasAndroidBackDestination } from '../../../src/platform/android/installAndroidBack';

// Android must retain ownership of the back-to-home gesture when there is no app destination.
describe('Android back destination', () => {
    it('leaves root and invalid history states to the operating system', () => {
        for (const index of [undefined, null, 0, -1, NaN, Infinity, 0.5, '1']) {
            expect(hasAndroidBackDestination(index, 0)).toBe(false);
        }
    });
    it('intercepts a real history destination or an open overlay', () => {
        expect(hasAndroidBackDestination(1, 0)).toBe(true);
        expect(hasAndroidBackDestination(0, 1)).toBe(true);
        expect(hasAndroidBackDestination(undefined, 2)).toBe(true);
    });
});

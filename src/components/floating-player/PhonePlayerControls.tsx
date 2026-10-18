import React, { useRef } from 'react';
import { usePhonePlayerGeometry } from '../../platform/android/usePhonePlayerGeometry';
import { useTranslation } from 'react-i18next';
import { Play, Pause, SkipBack, SkipForward } from 'lucide-react';
import { PlayerState } from '../../types';
import ProgressBar from '../ProgressBar';
import PlayerControlSlotButton from './PlayerControlSlotButton';
import type { ExpandedViewProps } from '../FloatingPlayerControls';

// A compact two-row phone transport keeps metadata and the three playback actions visible together.
const PhonePlayerControls: React.FC<ExpandedViewProps> = (props) => {
    const {
        currentSong, playerState, currentTime, duration, canTogglePlay, onSeek, onTogglePlay,
        noTrackText, primaryColor, secondaryColor, trackColor, isDaylight, controlsDisabled,
        trackNavigation, slotPrimary, slotSecondary, slotContext,
    } = props;
    const root = useRef<HTMLDivElement>(null);
    usePhonePlayerGeometry(root);
    const { t } = useTranslation();
    const artist = currentSong?.artists?.map(artist => artist.name).join(' / ');
    const buttonClass = 'flex h-11 w-11 shrink-0 items-center justify-center rounded-full disabled:opacity-25';
    return (
        <div ref={root} data-folia-phone-transport data-folia-seek-label={t('ui.seek')} className="flex w-full min-w-0 flex-col gap-1" style={{ color: primaryColor }}>
            <div className="flex min-w-0 items-center gap-1">
                <div className="min-w-0 flex-1 pl-1">
                    <div data-folia-track-title className="truncate text-sm font-semibold">{currentSong?.name || noTrackText}</div>
                    {artist && <div data-folia-track-artist className="truncate text-xs" style={{ color: secondaryColor }}>{artist}</div>}
                </div>
                {trackNavigation && <button type="button" className={buttonClass} data-folia-native-action="prev" aria-label={trackNavigation.prevLabel}
                    disabled={controlsDisabled || !trackNavigation.canPrev}
                    onClick={event => { event.stopPropagation(); trackNavigation.onPrev(); }}><SkipBack size={19} fill="currentColor" /></button>}
                <button type="button" className={buttonClass} data-folia-native-action="play" aria-label={t(playerState === PlayerState.PLAYING ? 'ui.pause' : 'ui.play')} disabled={controlsDisabled || !canTogglePlay}
                    style={{ backgroundColor: primaryColor, color: 'var(--bg-color)' }}
                    onClick={event => { event.stopPropagation(); onTogglePlay(); }}>
                    {playerState === PlayerState.PLAYING ? <Pause size={21} fill="currentColor" /> : <Play size={21} fill="currentColor" />}
                </button>
                {trackNavigation && <button type="button" className={buttonClass} data-folia-native-action="next" aria-label={trackNavigation.nextLabel}
                    disabled={controlsDisabled || !trackNavigation.canNext}
                    onClick={event => { event.stopPropagation(); trackNavigation.onNext(); }}><SkipForward size={19} fill="currentColor" /></button>}
            </div>
            <div className="flex min-w-0 items-center gap-1">
                <div data-folia-native-slot="primary" className="shrink-0"><PlayerControlSlotButton actionId={slotPrimary} context={slotContext} primaryColor={primaryColor}
                    isDaylight={isDaylight} controlsDisabled={controlsDisabled} className="shrink-0" /></div>
                <div className="min-w-0 flex-1"><ProgressBar currentTime={currentTime} duration={duration} onSeek={onSeek}
                    primaryColor={primaryColor} secondaryColor={secondaryColor} trackColor={trackColor} disabled={controlsDisabled} /></div>
                <div data-folia-native-slot="secondary" className="shrink-0"><PlayerControlSlotButton actionId={slotSecondary} context={slotContext} primaryColor={primaryColor}
                    isDaylight={isDaylight} controlsDisabled={controlsDisabled} className="shrink-0" /></div>
            </div>
        </div>
    );
};
export default PhonePlayerControls;

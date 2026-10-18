import React from 'react';
import { useTranslation } from 'react-i18next';
import { hideAppSplash } from '../../utils/appSplash';

// A renderer exception must leave a readable failure and retry action instead of removing the whole screen.
const StartupFailure: React.FC<{ error: Error }> = ({ error }) => {
    const { t } = useTranslation();
    return (
        <div role="alert" className="fixed inset-0 z-[2147483001] flex flex-col items-center justify-center gap-5 bg-zinc-950 px-6 text-center text-zinc-100">
            <h1 className="text-xl font-semibold">{t('ui.startupFailed')}</h1>
            <p className="max-w-lg break-words text-sm text-zinc-300">{error.message}</p>
            <p className="max-w-lg text-sm text-zinc-400">{t('ui.startupErrorHint')}</p>
            <button type="button" className="min-h-12 rounded-xl bg-zinc-100 px-6 font-semibold text-zinc-950" onClick={() => window.location.reload()}>{t('ui.startupRetry')}</button>
        </div>
    );
};
export class StartupErrorBoundary extends React.Component<React.PropsWithChildren, { error: Error | null }> {
    state: { error: Error | null } = { error: null };
    static getDerivedStateFromError(error: Error) { return { error }; }
    componentDidCatch(error: Error, info: React.ErrorInfo) {
        console.error('[Startup] Application renderer failed', error, info.componentStack);
        hideAppSplash();
    }
    render() { return this.state.error ? <StartupFailure error={this.state.error} /> : this.props.children; }
}

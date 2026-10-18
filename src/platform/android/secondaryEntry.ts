import { installAndroidBridge } from './installAndroidBridge';

// Restore preload ordering for the original desktop window documents.
void installAndroidBridge().then(async () => {
    for (const deferred of document.querySelectorAll<HTMLScriptElement>('script[type="application/folia-deferred"]')) {
        const script = document.createElement('script');
        for (const attribute of deferred.attributes) if (attribute.name !== 'type') script.setAttribute(attribute.name, attribute.value);
        script.textContent = deferred.textContent;
        deferred.replaceWith(script);
    }
    window.dispatchEvent(new Event('folia-android-ready'));
}).catch(error => console.error('[AndroidWindow] Preload failed', error));

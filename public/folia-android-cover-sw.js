// Capacitor bundles its application resources; only local cover routing needs a service worker.
importScripts('/folia-cover-sw.js');
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));

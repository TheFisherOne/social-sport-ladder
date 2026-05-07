// Tombstone service worker used only to retire legacy clients.
self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const cacheNames = await caches.keys();
      await Promise.all(cacheNames.map((name) => caches.delete(name)));
    } catch (error) {
      console.error('SW cleanup failed:', error);
    }

    await self.clients.claim();

    try {
      await self.registration.unregister();
    } catch (error) {
      console.error('SW unregister failed:', error);
    }
  })());
});

self.addEventListener('fetch', () => {
  // Intentionally empty: no interception while decommissioning service workers.
});

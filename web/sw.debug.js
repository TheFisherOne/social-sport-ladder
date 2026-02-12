
// sw.debug.js - FOR DEBUGGING ONLY

const cacheName = 'social-sport-ladder-cache-v1-debug';

// A minimal, safe list for debugging. This prevents errors when the full
// release file list is not present.
const resourcesToPrecache = [
  'index.html',
  'manifest.json',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'icons/apple-icon-180x180.png',
  'step-ladder.png',
  'assets/FontManifest.json',
  'assets/NOTICES',
  'assets/fonts/MaterialIcons-Regular.otf'
];

self.addEventListener('install', event => {
  console.log('DEBUG Service Worker: Install event in progress.');
  event.waitUntil(
    caches.open(cacheName)
      .then(cache => {
        console.log('DEBUG Service Worker: Caching pre-cached resources.');
        return cache.addAll(resourcesToPrecache);
      })
      .then(() => {
          console.log('DEBUG Service Worker: Install complete.');
          self.skipWaiting();
      })
      .catch(error => {
          console.error('DEBUG Service Worker: Caching failed:', error);
      })
  );
});

self.addEventListener('activate', event => {
  console.log('DEBUG Service Worker: Activate event in progress.');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.filter(name => name !== cacheName).map(name => caches.delete(name))
      );
    })
  );
});

self.addEventListener('fetch', event => {
  // In debug mode, a simple cache-first strategy is fine.
  // It will cache the thousands of small JS files on first load.
  event.respondWith(
    caches.match(event.request)
      .then(cachedResponse => {
        return cachedResponse || fetch(event.request);
      })
  );
});

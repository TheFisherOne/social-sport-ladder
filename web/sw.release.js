
// sw.js

const cacheName = 'social-sport-ladder-cache-v1';

// This list is tailored for a release build of a Flutter web app.
const resourcesToPrecache = [

    // The main compiled application code.
    'main.dart.js',

    // Essential Flutter web bootstrap scripts and manifests.
    'flutter.js',
    'manifest.json',

    // Icons and images.
    'icons/Icon-192.png',
    'icons/Icon-512.png',
    'icons/Icon-maskable-192.png',
    'icons/Icon-maskable-512.png',
    'icons/apple-icon-180x180.png',
    'step-ladder.png',

    // The Flutter engine (CanvasKit variant).
    'canvaskit/canvaskit.js',
    'canvaskit/canvaskit.wasm',
    'canvaskit/chromium/canvaskit.js',
    'canvaskit/chromium/canvaskit.wasm',

    // Asset manifests and fonts.
    'assets/AssetManifest.json',
    'assets/FontManifest.json',
    'assets/NOTICES',
    'assets/fonts/MaterialIcons-Regular.otf'
];

self.addEventListener('install', event => {
  console.log('Service Worker: Install event in progress.');
  event.waitUntil(
    caches.open(cacheName)
      .then(cache => {
        console.log('Service Worker: Caching pre-cached resources for release build.');
        return cache.addAll(resourcesToPrecache);
      })
      .then(() => {
          console.log('Service Worker: Install complete.');
          self.skipWaiting(); // Activate new service worker immediately
      })
      .catch(error => {
          console.error('Service Worker: Caching failed:', error);
      })
  );
});

self.addEventListener('activate', event => {
  console.log('Service Worker: Activate event in progress.');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.filter(name => name !== cacheName).map(name => caches.delete(name))
      );
    })
  );
});

self.addEventListener('fetch', event => {
  // Is this a navigation request (i.e., for the index.html page)?
  if (event.request.mode === 'navigate') {
    // this is basically only run on index.html as it is the only page that is entered in url
    event.respondWith(
      fetch(event.request)
        .then(response => {
          // If we get a response from the network, cache it for offline use and return it.
          const responseToCache = response.clone();
          caches.open(cacheName).then(cache => {
            cache.put(event.request, responseToCache);
          });
          return response;
        })
        .catch(() => {
          // If the network fails, return the cached version of index.html.
          return caches.match(event.request);
        })
    );
  } else {
    // No. For all other assets (JS, images, etc.), use a "Cache-First" strategy for speed.
    event.respondWith(
      caches.match(event.request).then(response => {
        return response || fetch(event.request);
      })
    );
  }
});

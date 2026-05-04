// sw.js

const swVersion = new URL(self.location.href).searchParams.get('v') || 'dev';
const cacheName = `social-sport-ladder-cache-${swVersion}`;

// This list is tailored for a release build of a Flutter web app.
const resourcesToPrecache = [
  // Core app shell.
  'index.html',
  'flutter_bootstrap.js',
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

  // Asset manifests and fonts.
  'assets/AssetManifest.json',
  'assets/FontManifest.json',
  'assets/NOTICES',
  'assets/fonts/MaterialIcons-Regular.otf',
];

self.addEventListener('install', event => {
  console.log('Service Worker: Install event in progress.');
  event.waitUntil(
    caches
      .open(cacheName)
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
      }),
  );
});

self.addEventListener('activate', event => {
  console.log('Service Worker: Activate event in progress.');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(cacheNames.filter(name => name !== cacheName).map(name => caches.delete(name)));
    }),
  );
});

self.addEventListener('fetch', event => {
  // Is this a navigation request (i.e., for the index.html page)?
  if (event.request.mode === 'navigate') {
    // This is typically for index.html.
    event.respondWith(
      fetch(event.request)
        .then(response => {
          // Cache successful navigation responses for offline use.
          const responseToCache = response.clone();
          caches.open(cacheName).then(cache => {
            cache.put(event.request, responseToCache);
          });
          return response;
        })
        .catch(() => {
          // If network fails, return cached navigation response.
          return caches.match(event.request);
        }),
    );
  } else {
    // For all other assets (JS, images, etc.), use a cache-first strategy for speed.
    event.respondWith(
      caches.match(event.request).then(response => {
        return response || fetch(event.request);
      }),
    );
  }
});

// sw.js - minimal service worker to satisfy Chrome's install criteria
self.addEventListener('fetch', event => {
  event.respondWith(fetch(event.request));
});
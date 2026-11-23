/* La compilación reemplaza los marcadores con archivos y hash de esta versión. */
const VERSION = "c8d0898ef3655b03";
const CACHE = `raices-shell-${VERSION}`;
const PRECACHE = ["avisos-sw.js","chunk-7aqp25Ku.js","chunk-BA3RGmto.js","chunk-BCJBNqdj.js","chunk-BXjpFDiq.js","chunk-BjmSKYmC.js","chunk-Blf4dC_3.js","chunk-BrbZ7Nrz.js","chunk-BxR_jkPf.js","chunk-C5uhTZgW.js","chunk-C7S0rOjH.js","chunk-CHj1T9ce.js","chunk-CI9KzZVl.js","chunk-CUmjHvfm.js","chunk-Cj4SYcWz.js","chunk-CjJ-Bamb.js","chunk-CjiV1-lI.js","chunk-CpgBK1Cd.js","chunk-D189xf7l.js","chunk-D1b2w7QB.js","chunk-D37l9zG0.js","chunk-D47EXnsq.js","chunk-DMk-GyWp.js","chunk-DYtvnHKt.js","chunk-Dc2-5yqR.js","chunk-DgWtvdL8.js","chunk-RmVkEvnA.js","chunk-l4KyWeyA.js","chunk-ujHw_3XA.js","favicon.ico","firebase-sw.js","icons/icon-192.png","icons/icon-512.png","index.html","main-WGBN6GHZ.js","manifest.webmanifest","media/layers-2x-TBM42ERR.png","media/layers-55W3Q4RM.png","media/marker-icon-2V3QKKVC.png","polyfills-LVNOU2XZ.js","styles-4H4TLDNE.css"];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(PRECACHE.map(path => new URL(path, self.registration.scope).href))));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('raices-shell-') && key !== CACHE).map(key => caches.delete(key)))));
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  const scope = new URL(self.registration.scope);
  if (event.request.method !== 'GET' || url.origin !== scope.origin || event.request.headers.has('Authorization')) return;
  // Solo se almacena el shell público. Los datos empresariales van a IndexedDB por cuenta.
  if (event.request.mode === 'navigate' && url.pathname.startsWith(scope.pathname)) {
    event.respondWith(fetch(event.request).catch(() => caches.open(CACHE).then(cache => cache.match(new URL('index.html', scope).href))));
    return;
  }
  const known = PRECACHE.some(path => new URL(path, scope).href === url.href);
  if (known) event.respondWith(caches.open(CACHE).then(async cache => (await cache.match(event.request)) || fetch(event.request)));
});

/* La compilación reemplaza los marcadores con archivos y hash de esta versión. */
const VERSION = "3cc910128794555e";
const CACHE = `raices-shell-${VERSION}`;
const PRECACHE = ["chunk-7aqp25Ku.js","chunk-B1Q0UTBh.js","chunk-C7S0rOjH.js","chunk-CUmjHvfm.js","chunk-Cj4SYcWz.js","chunk-CjiV1-lI.js","chunk-CpgBK1Cd.js","chunk-D189xf7l.js","chunk-D1b2w7QB.js","chunk-D47EXnsq.js","chunk-Dc2-5yqR.js","chunk-Dxu23Y-X.js","chunk-OlYYUlKe.js","chunk-fjY2nF9V.js","chunk-kYG0qaRD.js","favicon.ico","icons/icon-192.png","icons/icon-512.png","index.html","main-QUB56P65.js","manifest.webmanifest","polyfills-LVNOU2XZ.js","styles-5MUOB3BF.css"];
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

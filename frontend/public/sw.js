/* La compilación reemplaza los marcadores con archivos y hash de esta versión. */
const VERSION = '__BUILD_VERSION__';
const CACHE = `raices-shell-${VERSION}`;
const PRECACHE = __PRECACHE__;
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

/* Idle KardRune PWA: cache public static assets only.
 * Never cache /api/ responses, authenticated requests, WebSockets or video.
 * This also supersedes the legacy /idle/sw.js cache on activation.
 */
const CACHE_NAME = 'idle-kardrune-flutter-v2';
const SCOPE = new URL(self.registration.scope);
const SHELL = ['./', './index.html', './manifest.json', './flutter_bootstrap.js'];
const STATIC_FILES = new Set([
  '', 'index.html', 'manifest.json', 'flutter_bootstrap.js', 'flutter.js',
  'main.dart.js', 'favicon.png', 'kardrune_service_worker.js',
]);
function cacheable(request) {
  if (request.method !== 'GET' || request.headers.has('authorization') ||
      request.headers.has('range') || request.cache === 'no-store') return false;
  const url = new URL(request.url);
  if (url.origin !== SCOPE.origin || !url.pathname.startsWith(SCOPE.pathname)) return false;
  const relative = url.pathname.slice(SCOPE.pathname.length);
  if (relative.startsWith('api/') || /\.(mp4|webm)$/i.test(relative)) return false;
  return STATIC_FILES.has(relative) ||
      /^(assets|canvaskit|icons)\//.test(relative) ||
      /\.(?:js|wasm|json|png|svg|webp|bin|ttf|otf)$/.test(relative);
}
self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL)));
});
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((key) => key.startsWith('idle-kardrune-') && key !== CACHE_NAME)
        .map((key) => caches.delete(key)),
    )).then(() => self.clients.claim()),
  );
});
self.addEventListener('fetch', (event) => {
  if (!cacheable(event.request)) return;
  const request = event.request;
  event.respondWith(
    fetch(request).then((response) => {
      if (response.ok && response.type === 'basic' &&
          !/no-store|private/i.test(response.headers.get('cache-control') || '')) {
        const copy = response.clone();
        event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.put(request, copy)).catch(() => {}));
      }
      return response;
    }).catch(async () => (await caches.match(request)) || Response.error()),
  );
});

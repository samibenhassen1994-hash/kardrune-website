/* Idle KardRune PWA: cache public static assets only.
 * Never cache /api/ responses, authenticated requests, WebSockets or video.
 * This also supersedes the legacy /idle/sw.js cache on activation.
 */
const RELEASE = 'b5ace12';
const CACHE_NAME = `idle-kardrune-flutter-${RELEASE}`;
const SCOPE = new URL(self.registration.scope);
const SHELL = ['./', './index.html', './manifest.json', './flutter_bootstrap.js', './main.dart.js'];
const CORE_ASSETS = [
  './arena_loading.webp',
  './boot-loading.js',
  './assets/assets/idle/arena/arena_background.webp',
  './assets/assets/idle/arena/background_deck.webp',
  './assets/assets/idle/arena/background_fight_idlearena.webp',
  './assets/assets/idle/arena/shard.webp',
  './assets/assets/idle/summon/summon_arena.webp',
];
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
  if (relative === 'release-id.json' || relative.startsWith('api/') || /\.(mp3|mp4|webm)$/i.test(relative)) return false;
  return STATIC_FILES.has(relative) ||
      /^(assets|canvaskit|icons)\//.test(relative) ||
      /\.(?:js|wasm|json|png|svg|webp|mp3|bin|ttf|otf)$/.test(relative);
}
function versionedUrl(request) {
  const url = new URL(request.url);
  url.searchParams.set('krv', RELEASE);
  return url;
}
async function fetchFresh(request) {
  // The release query also bypasses Cloudflare and WebView's HTTP cache for
  // same-path assets, while the original URL remains the offline cache key.
  return fetch(versionedUrl(request), { cache: 'reload' });
}
self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.all([...SHELL, ...CORE_ASSETS].map(async (path) => {
      const request = new Request(new URL(path, SCOPE));
      const response = await fetchFresh(request);
      if (!response.ok) throw Error(`PWA preload failed: ${path}`);
      await cache.put(request, response);
    }));
  })());
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
    fetchFresh(request).then((response) => {
      if (response.ok &&
          !/no-store|private/i.test(response.headers.get('cache-control') || '')) {
        const copy = response.clone();
        event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.put(request, copy)).catch(() => {}));
      }
      return response;
    }).catch(async () => (await caches.match(request)) || Response.error()),
  );
});

self.addEventListener('push',event=>{
  event.waitUntil((async()=>{
    let data={};try{data=event.data?.json()||{}}catch(_){}
    const free=data.topic==='free_pull';
    await self.registration.showNotification(free?'KardRune · Free Summon':'KardRune',{
      body:free?'A free Standard Summon is ready.':'New activity in KardRune.',
      tag:typeof data.id==='string'?data.id:'kardrune',icon:'icons/Icon-192.png',
      renotify:false,
      data:{url:'./'}
    });
  })());
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const targets=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const tab=targets.find(t=>t.url.startsWith(self.registration.scope));
    if(tab)await tab.focus();else await self.clients.openWindow(self.registration.scope);
  })());
});

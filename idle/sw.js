const CACHE='idle-kardrune-shell-v4';
const CORE=['./','./index.html','./styles.css','./app.js','./game-rules.js','./catalog.js','./icon.svg','./manifest.webmanifest'];
const IMAGES=[...Array(0)];
const OWN_PREFIX='idle-kardrune-';
const allowed = url => url.origin===self.location.origin && url.pathname.startsWith(new URL('./',self.registration.scope).pathname);
self.addEventListener('install',event=>{
 event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(CORE)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',event=>{
 event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith(OWN_PREFIX)&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',event=>{
 const req=event.request;
 if(req.method!=='GET'||req.headers.has('range')||!allowed(new URL(req.url)))return;
 const path=new URL(req.url).pathname;
 const isVideo=/\.mp4$/i.test(path);
 if(isVideo)return; // Stream videos normally; never cache multi-megabyte video responses.
 event.respondWith(
  caches.match(req).then(cached=>cached||fetch(req).then(response=>{
   if(response.ok&&response.type==='basic') {
    const copy=response.clone();
    event.waitUntil(caches.open(CACHE).then(cache=>cache.put(req,copy)).catch(()=>{}));
   }
   return response;
  }))
 );
});

const CACHE='idle-kardrune-shell-v30';
const CORE=['./','./index.html','./styles.css','./app.js','./game-rules.js','./combat-rules.js','./i18n.js','./cloud-sync-rules.js','./cloud.js','./pvp.js','./deck-layout.js','./deck-drag.js','./live-pvp.js','./pvp-arena.js','./update.js','./catalog.js','./icon.svg','./manifest.webmanifest'];
const IMAGES=[
 "./media/cards/young_sam/young_sam_stage_1.webp",
 "./media/cards/young_sam/sam_of_aster_stage_2.webp",
 "./media/cards/young_sam/Sam_Last_Guardian_stage_3.webp",
 "./media/cards/lira/lira_stage_1.webp",
 "./media/cards/lira/lira_stage_2.webp",
 "./media/cards/lira/lira_stage_3.webp",
 "./media/cards/rhea/rhea_stage_1.webp",
 "./media/cards/rhea/rhea_ranger_stage_2.webp",
 "./media/cards/rhea/Rhea_Guardian_of_the_Ruins_stage_3.webp",
 "./media/cards/dren/dren_stage_1.webp",
 "./media/cards/dren/dren_stage_2.webp",
 "./media/cards/dren/dren_stage_3.webp",
 "./media/cards/tor/tor_stage_1.webp",
 "./media/cards/tor/tor_stage_2.webp",
 "./media/cards/tor/tor_stage_3.webp",
 "./media/cards/aria/aria_stage_1.webp",
 "./media/cards/aria/aria_crimson_arcanist_stage_2.webp",
 "./media/cards/aria/Aria_Fallen_Arcanist_stage_3.webp",
 "./media/cards/kael/kael_stage_1.webp",
 "./media/cards/kael/kael_stage_2.webp",
 "./media/cards/kael/kael_stage_3.webp",
 "./media/cards/neris/neris_stage_1.webp",
 "./media/cards/neris/neris_stage_2.webp",
 "./media/cards/neris/neris_stage_3.webp",
 "./media/cards/nyra/nyra_stage_1.webp",
 "./media/cards/nyra/nyra_stage_2.webp",
 "./media/cards/nyra/nyra_stage_3.webp",
 "./media/avatars/avatar_player.webp",
 "./media/avatars/avatar_guard.webp",
 "./media/avatars/avatar_vassal.webp",
 "./media/avatars/avatar_king.webp"
];
const OWN_PREFIX='idle-kardrune-';
const allowed = url => url.origin===self.location.origin && url.pathname.startsWith(new URL('./',self.registration.scope).pathname);
self.addEventListener('install',event=>{
 event.waitUntil(caches.open(CACHE).then(async cache=>{await cache.addAll(CORE);await Promise.allSettled(IMAGES.map(path=>cache.add(path)));}).then(()=>self.skipWaiting()));
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
  ( /\.(?:js|css|html)$/.test(path) || path.endsWith('/idle/') ? fetch(req).then(response=>{
   const cacheable=CORE.concat(IMAGES).some(asset=>new URL(asset,self.registration.scope).pathname===path);
   if(cacheable&&response.ok&&response.type==='basic') {
    const copy=response.clone();
    event.waitUntil(caches.open(CACHE).then(cache=>cache.put(req,copy)).catch(()=>{}));
   }
   return response;
  }).catch(()=>caches.match(req).then(cached=>cached||Response.error())) : caches.match(req).then(cached=>cached||fetch(req).then(response=>{
   if(response.ok&&response.type==='basic'&&IMAGES.some(asset=>new URL(asset,self.registration.scope).pathname===path)){
    const copy=response.clone();event.waitUntil(caches.open(CACHE).then(cache=>cache.put(req,copy)).catch(()=>{}));
   }
   return response;
  })) )
 );
});

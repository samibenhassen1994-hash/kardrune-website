import {authorizeAsset} from '../../api/admin/arena-access.js';
import {failure} from '../../api/_lib/auth.js';
export async function onRequest({request,env}) {
  try {
    await authorizeAsset(request,env);
    const asset=await env.ASSETS.fetch(request);
    const headers=new Headers(asset.headers);
    headers.set('Cache-Control','private, no-store');
    return new Response(asset.body,{status:asset.status,headers});
  } catch(e) {
    return new Response('Accesso riservato. Apri la home di KardRune Idle con il tuo account amministratore.',{
      status:failure(e).status,headers:{'Cache-Control':'private, no-store','Content-Type':'text/plain; charset=utf-8'}});
  }
}

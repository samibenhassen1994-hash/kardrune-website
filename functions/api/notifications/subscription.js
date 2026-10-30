import {failure} from '../_lib/auth.js';
import {authed,readPayload,validSubscription,json} from './_lib.js';
export async function onRequestPost({request,env}) {
  try {
    const user=await authed(request,env);
    const body=await readPayload(request);
    if (!validSubscription(body.subscription)) return json({error:'Invalid push subscription'},400);
    if (!env.VAPID_PUBLIC_KEY) return json({error:'Web Push is not configured'},503);
    const sub=body.subscription, now=Date.now();
    const canonical=JSON.stringify({endpoint:sub.endpoint,expirationTime:null,
      keys:{p256dh:sub.keys.p256dh,auth:sub.keys.auth}});
    const owned=await env.DB.prepare('SELECT uid FROM push_subscriptions WHERE endpoint=?')
      .bind(sub.endpoint).first();
    if (owned && owned.uid!==user.uid) return json({error:'This device belongs to another account. Turn off notifications on this device first.'},409);
    await env.DB.prepare(`INSERT INTO push_subscriptions(endpoint,uid,subscription_json,created_at,updated_at)
      VALUES(?,?,?,?,?) ON CONFLICT(endpoint) DO UPDATE SET
      subscription_json=excluded.subscription_json,updated_at=excluded.updated_at`)
      .bind(sub.endpoint,user.uid,canonical,now,now).run();
    // Cap active devices, oldest first, to limit abuse and quotas.
    await env.DB.prepare(`DELETE FROM push_subscriptions WHERE uid=? AND endpoint NOT IN
       (SELECT endpoint FROM push_subscriptions WHERE uid=? ORDER BY updated_at DESC LIMIT 5)`)
      .bind(user.uid,user.uid).run();
    return json({ok:true});
  } catch(error){return failure(error)}
}
export async function onRequestDelete({request,env}) {
  try {
    const user=await authed(request,env);
    const body=await readPayload(request);
    if(typeof body.endpoint!=='string'||body.endpoint.length>2048) return json({error:'Invalid endpoint'},400);
    await env.DB.prepare('DELETE FROM push_subscriptions WHERE uid=? AND endpoint=?')
      .bind(user.uid,body.endpoint).run();
    return json({ok:true});
  }catch(error){return failure(error)}
}

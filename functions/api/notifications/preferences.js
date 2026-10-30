import {failure} from '../_lib/auth.js';
import {authed,readPayload,TOPICS,json} from './_lib.js';
export async function onRequestGet({request,env}) {
  try {
    const user=await authed(request,env);
    const rows=await env.DB.prepare('SELECT topic,enabled FROM notification_preferences WHERE uid=?')
      .bind(user.uid).all();
    const preferences={free_pull:false};
    for(const row of rows.results||[]) if(TOPICS.has(row.topic)) preferences[row.topic]=row.enabled===1;
    return json({preferences});
  }catch(error){return failure(error)}
}
export async function onRequestPut({request,env}) {
  try {
    const user=await authed(request,env);
    const body=await readPayload(request);
    if(!TOPICS.has(body.topic)||typeof body.enabled!=='boolean') return json({error:'Invalid notification preference'},400);
    await env.DB.prepare(`INSERT INTO notification_preferences(uid,topic,enabled,updated_at)
      VALUES(?,?,?,?) ON CONFLICT(uid,topic) DO UPDATE SET enabled=excluded.enabled,
      updated_at=excluded.updated_at`)
      .bind(user.uid,body.topic,body.enabled?1:0,Date.now()).run();
    return json({ok:true,topic:body.topic,enabled:body.enabled});
  }catch(error){return failure(error)}
}

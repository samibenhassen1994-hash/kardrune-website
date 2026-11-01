import {userFromRequest,failure,json} from './_lib/auth.js';
import {ensureNameChoices,chosenNameFor} from './_lib/name_store.js';
export async function onRequestGet({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  await env.DB.prepare('INSERT OR IGNORE INTO players (uid, display_name) VALUES (?,?)').bind(user.uid,user.name).run();
  await ensureNameChoices(env);
  const chosenName=await chosenNameFor(env,user.uid);
  const player=await env.DB.prepare('SELECT uid,display_name,avatar,created_at FROM players WHERE uid=?').bind(user.uid).first();
  const role=await env.DB.prepare('SELECT role FROM player_roles WHERE uid=?').bind(user.uid).first();
  return json({player:{...player,...(chosenName?{display_name:chosenName}:{})},nameChosen:chosenName!==null,role:role?.role||'player'});
 }catch(e){return failure(e)}
}

import {userFromRequest,failure,json} from './_lib/auth.js';
export async function onRequestGet({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  await env.DB.prepare('INSERT OR IGNORE INTO players (uid, display_name) VALUES (?,?)').bind(user.uid,user.name).run();
  const player=await env.DB.prepare('SELECT uid,display_name,avatar,created_at FROM players WHERE uid=?').bind(user.uid).first();
  const role=await env.DB.prepare('SELECT role FROM player_roles WHERE uid=?').bind(user.uid).first();
  return json({player,role:role?.role||'player'});
 }catch(e){return failure(e)}
}

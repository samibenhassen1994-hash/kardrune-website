import {userFromRequest,failure,json} from '../_lib/auth.js';
export async function onRequestGet({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'Database not configured'},503);
  const role=await env.DB.prepare('SELECT role FROM player_roles WHERE uid=?').bind(user.uid).first();
  if(role?.role!=='admin')return json({error:'Forbidden'},403);
  const [players,saves,duels,tournaments]=await Promise.all([
   env.DB.prepare('SELECT COUNT(*) AS count FROM players').first(),
   env.DB.prepare('SELECT COUNT(*) AS count FROM demo_saves').first(),
   env.DB.prepare('SELECT COUNT(*) AS count FROM pvp_matches').first(),
   env.DB.prepare('SELECT COUNT(*) AS count FROM tournaments').first()
  ]);
  return json({players:players?.count||0,demoSaves:saves?.count||0,pvpMatches:duels?.count||0,tournaments:tournaments?.count||0});
 }catch(e){return failure(e)}
}

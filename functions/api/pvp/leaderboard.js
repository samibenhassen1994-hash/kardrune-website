import {userFromRequest,json,failure} from '../_lib/auth.js';
import {requireActiveAccount} from '../_lib/account_status.js';
import {ranking,ensureRankedSchema} from '../_lib/ranked_store.js';
export async function onRequestGet({request,env}){
 try{
  if(!env.DB)return json({error:'Database unavailable'},503);
  const user=await userFromRequest(request,env);
  await requireActiveAccount(env,user.uid);
  await ensureRankedSchema(env);
  const data=await ranking(env,user.uid);
  const top=data.top;
  let names=[];
  if(top.length){
   const marks=top.map(()=>'?').join(',');
   names=(await env.DB.prepare(`SELECT uid,display_name FROM players WHERE uid IN (${marks})`)
    .bind(...top.map(x=>x.uid)).all()).results||[];
  }
  const byUid=new Map(names.map(n=>[n.uid,n.display_name]));
  const claims=(await env.DB.prepare('SELECT league FROM pvp_league_claims WHERE uid=?').bind(user.uid).all()).results||[];
  return json({you:data.mine,leaders:top.map(({uid,wins,points},i)=>({
   name:byUid.get(uid)||'Runebearer',wins,points,league:data.leagues.findLast(x=>points>=x.points)?.name||'Bronze',
   position:i+1,isYou:uid===user.uid
  })),leagues:data.leagues,claimed:claims.map(c=>c.league),pointsPerWin:data.pointsPerWin});
 }catch(e){return failure(e)}
}

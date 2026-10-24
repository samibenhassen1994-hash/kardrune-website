import {context,cardFromCloud,fight,json,failure} from '../_lib/pvp.js';
export async function onRequestPost({request,env}){
 try{
  const user=await context(request,env),now=Date.now(),ticket=crypto.randomUUID();
  const current=await env.DB.prepare('SELECT match_id FROM pvp_friendly_queue WHERE uid=?').bind(user.uid).first();
  if(current?.match_id)return json({state:'matched',matchId:current.match_id});
  if(current)return json({state:'waiting'});
  const card=await cardFromCloud(env,user.uid);
  if(!card)return json({error:'Save your active card to the cloud first'},400);
  await env.DB.prepare('INSERT OR IGNORE INTO pvp_friendly_queue(uid,ticket,card_json,joined_at,match_id) VALUES(?,?,?,?,NULL)')
    .bind(user.uid,ticket,JSON.stringify(card),now).run();
  // A lock-free matchmaking claim is guarded by a single conditional UPDATE.
  const opponent=await env.DB.prepare('SELECT q.uid,q.ticket,q.card_json FROM pvp_friendly_queue q JOIN players p ON p.uid=q.uid WHERE q.uid<>? AND q.match_id IS NULL AND q.joined_at>=? AND p.is_banned=0 ORDER BY q.joined_at LIMIT 1').bind(user.uid,now-300000).first();
  if(!opponent)return json({state:'waiting'});
  const matchId=crypto.randomUUID();
  const claimed=await env.DB.prepare('UPDATE pvp_friendly_queue SET match_id=? WHERE uid=? AND ticket=? AND match_id IS NULL AND joined_at>=?').bind(matchId,opponent.uid,opponent.ticket,now-300000).run();
  if(claimed.meta?.changes!==1)return json({state:'waiting'});
  try{
   const own=await env.DB.prepare('UPDATE pvp_friendly_queue SET match_id=? WHERE uid=? AND ticket=? AND match_id IS NULL').bind(matchId,user.uid,ticket).run();
   if(own.meta?.changes!==1)throw Error('Current player is no longer queued');
   const cardB=JSON.parse(opponent.card_json),result=fight(card,cardB);
   const winner=result.winner===0?user.uid:opponent.uid;
   await env.DB.prepare('INSERT INTO pvp_friendly_matches(id,player_a,player_b,card_a_json,card_b_json,replay_json,winner_uid,created_at) VALUES(?,?,?,?,?,?,?,?)')
    .bind(matchId,user.uid,opponent.uid,JSON.stringify(card),JSON.stringify(cardB),JSON.stringify(result.log),winner,now).run();
   return json({state:'matched',matchId});
  }catch(e){
   await env.DB.prepare('DELETE FROM pvp_friendly_queue WHERE match_id=?').bind(matchId).run();
   throw e;
  }
 }catch(e){return failure(e)}
}

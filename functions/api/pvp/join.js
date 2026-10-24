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
  const opponent=await env.DB.prepare(
   'SELECT q.uid,q.ticket,q.card_json FROM pvp_friendly_queue q JOIN players p ON p.uid=q.uid WHERE q.uid<>? AND q.match_id IS NULL AND q.joined_at>=? AND p.is_banned=0 ORDER BY q.joined_at LIMIT 1'
  ).bind(user.uid,now-300000).first();
  if(!opponent)return json({state:'waiting'});
  const matchId=crypto.randomUUID();
  const cardB=JSON.parse(opponent.card_json),result=fight(card,cardB);
  const winner=result.winner===0?user.uid:opponent.uid;
  // D1 batch runs as one transaction. The INSERT checks both queue tickets,
  // so simultaneous matchmakers cannot pair one player twice.
  const statements=[
   env.DB.prepare(`INSERT INTO pvp_friendly_matches(id,player_a,player_b,card_a_json,card_b_json,replay_json,winner_uid,created_at)
    SELECT ?,a.uid,b.uid,a.card_json,b.card_json,?,?,?
    FROM pvp_friendly_queue a JOIN pvp_friendly_queue b ON a.uid<>b.uid
    WHERE a.uid=? AND a.ticket=? AND a.match_id IS NULL
      AND b.uid=? AND b.ticket=? AND b.match_id IS NULL`)
    .bind(matchId,JSON.stringify(result.log),winner,now,user.uid,ticket,opponent.uid,opponent.ticket),
   env.DB.prepare('UPDATE pvp_friendly_queue SET match_id=? WHERE uid IN (?,?) AND match_id IS NULL AND EXISTS(SELECT 1 FROM pvp_friendly_matches WHERE id=?)')
    .bind(matchId,user.uid,opponent.uid,matchId)
  ];
  const committed=await env.DB.batch(statements);
  if(committed[0]?.meta?.changes!==1)return json({state:'waiting'});
  return json({state:'matched',matchId});
 }catch(e){return failure(e)}
}

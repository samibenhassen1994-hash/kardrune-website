import {context,json,failure} from '../_lib/pvp.js';
export async function onRequestGet({request,env}){
 try{
  const user=await context(request,env);
  const queue=await env.DB.prepare('SELECT match_id FROM pvp_friendly_queue WHERE uid=?').bind(user.uid).first();
  if(!queue)return json({state:'idle'});
  if(!queue.match_id)return json({state:'waiting'});
  const row=await env.DB.prepare('SELECT m.*,a.display_name AS name_a,b.display_name AS name_b FROM pvp_friendly_matches m JOIN players a ON a.uid=m.player_a JOIN players b ON b.uid=m.player_b WHERE m.id=? AND (m.player_a=? OR m.player_b=?)').bind(queue.match_id,user.uid,user.uid).first();
  if(!row)return json({state:'waiting'});
  const yourIndex=row.player_a===user.uid?0:1;
  return json({state:'matched',matchId:row.id,won:row.winner_uid===user.uid,
    you:{name:yourIndex===0?row.name_a:row.name_b,card:JSON.parse(yourIndex===0?row.card_a_json:row.card_b_json)},
    opponent:{name:yourIndex===0?row.name_b:row.name_a,card:JSON.parse(yourIndex===0?row.card_b_json:row.card_a_json)},
    replay:JSON.parse(row.replay_json).map(turn=>({...turn,actor:turn.actor===yourIndex?'you':'opponent'}))});
 }catch(e){return failure(e)}
}

import {context,choice,json,failure} from '../_lib/pvp.js';
function validate(save,ids){
 if(!Array.isArray(ids)||ids.length<1||ids.length>9||new Set(ids).size!==ids.length)return false;
 return ids.every(id=>typeof id==='string'&&save.owned?.includes(id)&&choice({...save,active:id})!==null);
}
export async function onRequestGet({request,env}){
 try{const user=await context(request,env);
 const row=await env.DB.prepare('SELECT cards_json FROM pvp_decks WHERE uid=?').bind(user.uid).first();
 return json({cards:row?JSON.parse(row.cards_json):[]});
 }catch(e){return failure(e)}
}
export async function onRequestPut({request,env}){
 try{const user=await context(request,env);
 const raw=await request.text();if(raw.length>1500)return json({error:'Deck too large'},413);
 let ids;try{ids=JSON.parse(raw).cards}catch{return json({error:'Invalid deck'},400)}
 const row=await env.DB.prepare('SELECT save_json FROM demo_saves WHERE uid=?').bind(user.uid).first();
 if(!row)return json({error:'Cloud save required'},400);
 if(!validate(JSON.parse(row.save_json),ids))return json({error:'Select 1–9 distinct owned cards with valid stats'},400);
 await env.DB.prepare('INSERT INTO pvp_decks(uid,cards_json,updated_at) VALUES(?,?,?) ON CONFLICT(uid) DO UPDATE SET cards_json=excluded.cards_json,updated_at=excluded.updated_at')
 .bind(user.uid,JSON.stringify(ids),Date.now()).run();
 return json({cards:ids});
 }catch(e){return failure(e)}
}

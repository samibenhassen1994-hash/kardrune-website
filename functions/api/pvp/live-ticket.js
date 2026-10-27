import {context,choice,json,failure} from '../_lib/pvp.js';
export async function onRequestPost({request,env}){
 try{
 const user=await context(request,env);
 if(!env.LIVE_PVP_URL)return json({error:'Live PvP server is not deployed yet'},503);
 const row=await env.DB.prepare('SELECT d.cards_json,s.save_json FROM pvp_decks d JOIN demo_saves s ON s.uid=d.uid WHERE d.uid=?').bind(user.uid).first();
 if(!row)return json({error:'Save and configure your deck first (at least 3 cards)'},400);
 const save=JSON.parse(row.save_json),ids=JSON.parse(row.cards_json);
 if(!Array.isArray(ids)||ids.length<3||ids.length>9||new Set(ids).size!==ids.length||ids.some(id=>!save.owned?.includes(id)||!choice({...save,active:id})))return json({error:'A best-of-three match requires at least 3 distinct owned cards saved in your deck'},400);
 const ticket=crypto.randomUUID(),expires=Date.now()+45000;
 await env.DB.prepare('INSERT INTO pvp_live_tickets(uid,ticket,expires_at) VALUES(?,?,?) ON CONFLICT(uid) DO UPDATE SET ticket=excluded.ticket,expires_at=excluded.expires_at').bind(user.uid,ticket,expires).run();
 return json({url:env.LIVE_PVP_URL,ticket,expiresAt:expires});
 }catch(e){return failure(e)}
}

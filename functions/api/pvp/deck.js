import {context,choice,json,failure} from '../_lib/pvp.js';
import {ensureLegacySkills} from '../_lib/skill_store.js';
import {validSkillForStage,SKILL_VERSION} from '../../../shared/skill_catalog.js';
// An existing D1 database may have 0001/0002 but not the 0003 deck table yet.
// Initialize only this non-competitive table on first access; the rest of 0003
// remains a separate, explicit migration for the live-match Worker.
const DECK_SCHEMA='CREATE TABLE IF NOT EXISTS pvp_decks (uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE, cards_json TEXT NOT NULL, updated_at INTEGER NOT NULL)';
async function deckQuery(env,operation){
 try{return await operation()}
 catch(error){
  if(!/no such table:\s*(?:main\.)?pvp_decks/i.test(String(error?.message||error)))throw error;
  await env.DB.prepare(DECK_SCHEMA).run();
  return operation();
 }
}
function validate(save,ids){
 if(!Array.isArray(ids)||ids.length<1||ids.length>9||new Set(ids).size!==ids.length)return false;
 return ids.every(id=>typeof id==='string'&&save.owned?.includes(id)&&choice({...save,active:id})!==null);
}
export async function onRequestGet({request,env}){
 try{
  const user=await context(request,env);
  const row=await deckQuery(env,()=>env.DB.prepare('SELECT cards_json FROM pvp_decks WHERE uid=?').bind(user.uid).first());
  return json({cards:row?JSON.parse(row.cards_json):[]});
 }catch(e){return failure(e)}
}
export async function onRequestPut({request,env}){
 try{
  const user=await context(request,env);
  const raw=await request.text();if(raw.length>1500)return json({error:'Deck too large'},413);
  let ids;try{ids=JSON.parse(raw).cards}catch{return json({error:'Invalid deck'},400)}
  const row=await env.DB.prepare('SELECT save_json FROM demo_saves WHERE uid=?').bind(user.uid).first();
  if(!row)return json({error:'Cloud save required before saving a deck'},400);
  if(!validate(JSON.parse(row.save_json),ids))return json({error:'Deck cards do not match the latest cloud save. Wait for cloud backup and try again (1–9 distinct owned cards).'},409);
  const grants=await ensureLegacySkills(env,user.uid);
  if(!ids.every(id=>grants.some(g=>g.card_id===id&&g.skill_version===SKILL_VERSION&&
    validSkillForStage(g.skill_id,Number(id.split(':')[1])))))
   return json({error:'Deck contains an unverified card. Summon online or choose a verified card.'},409);
  await deckQuery(env,()=>env.DB.prepare('INSERT INTO pvp_decks(uid,cards_json,updated_at) VALUES(?,?,?) ON CONFLICT(uid) DO UPDATE SET cards_json=excluded.cards_json,updated_at=excluded.updated_at')
   .bind(user.uid,JSON.stringify(ids),Date.now()).run());
  return json({cards:ids});
 }catch(e){return failure(e)}
}

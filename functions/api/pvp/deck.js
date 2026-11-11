import {context,choice,json,failure} from '../_lib/pvp.js';
import {ensureLegacySkills} from '../_lib/skill_store.js';
import {ensureStarterCards,fillDeck} from '../_lib/starter_deck.js';
import {validSkillForCard,SKILL_VERSION} from '../../../shared/skill_catalog.js';
// An existing D1 database may have 0001/0002 but not the 0003 deck table yet.
// Initialize only this non-competitive table on first access; the rest of 0003
// remains a separate, explicit migration for the live-match Worker.
const DECK_SCHEMA='CREATE TABLE IF NOT EXISTS pvp_decks (uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE, cards_json TEXT NOT NULL, updated_at INTEGER NOT NULL, revision INTEGER NOT NULL DEFAULT 1)';
async function deckQuery(env,operation){
 try{return await operation()}
 catch(error){
  if(!/no such table:\s*(?:main\.)?pvp_decks/i.test(String(error?.message||error)))throw error;
  await env.DB.prepare(DECK_SCHEMA).run();
  return operation();
 }
}
function validate(save,ids){
 if(!Array.isArray(ids)||ids.length!==9||new Set(ids).size!==ids.length)return false;
 return ids.every(id=>typeof id==='string'&&save.owned?.includes(id)&&choice({...save,active:id})!==null);
}
export async function onRequestGet({request,env}){
 try{
  const user=await context(request,env);
  let saveRow=await env.DB.prepare('SELECT save_json,revision FROM demo_saves WHERE uid=?').bind(user.uid).first();
  if(!saveRow)return json({cards:[],revision:0});
  let grants=await ensureLegacySkills(env,user.uid);
  ({row:saveRow,grants}=await ensureStarterCards(env,user.uid,saveRow,grants));
  const save=JSON.parse(saveRow.save_json);
  const row=await deckQuery(env,()=>env.DB.prepare('SELECT cards_json,revision FROM pvp_decks WHERE uid=?').bind(user.uid).first());
  const previous=row?JSON.parse(row.cards_json):[];
  const complete=fillDeck(previous,save,grants);
  if(complete.length!==9)return json({cards:previous,revision:row?.revision??0});
  if(JSON.stringify(previous)===JSON.stringify(complete))return json({cards:previous,revision:row?.revision??0});
  const write=await deckQuery(env,()=>row
   ?env.DB.prepare('UPDATE pvp_decks SET cards_json=?,updated_at=?,revision=revision+1 WHERE uid=? AND revision=?').bind(JSON.stringify(complete),Date.now(),user.uid,row.revision).run()
   :env.DB.prepare('INSERT INTO pvp_decks(uid,cards_json,updated_at,revision) VALUES(?,?,?,1) ON CONFLICT(uid) DO NOTHING').bind(user.uid,JSON.stringify(complete),Date.now()).run());
  if(write.meta?.changes!==1){const latest=await env.DB.prepare('SELECT cards_json,revision FROM pvp_decks WHERE uid=?').bind(user.uid).first();return json({cards:JSON.parse(latest.cards_json),revision:latest.revision});}
  return json({cards:complete,revision:(row?.revision??0)+1});
 }catch(e){return failure(e)}
}
export async function onRequestPut({request,env}){
 try{
  const user=await context(request,env);
  const raw=await request.text();if(raw.length>1500)return json({error:'Deck too large'},413);
  let ids,revision;try{const body=JSON.parse(raw);ids=body.cards;revision=body.revision}catch{return json({error:'Invalid deck'},400)}
  if(!Number.isSafeInteger(revision)||revision<0)return json({error:'Deck revision required'},400);
  const row=await env.DB.prepare('SELECT save_json FROM demo_saves WHERE uid=?').bind(user.uid).first();
  if(!row)return json({error:'Cloud save required before saving a deck'},400);
  if(!validate(JSON.parse(row.save_json),ids))return json({error:'Deck cards do not match the latest cloud save. Wait for cloud backup and try again (9 distinct owned cards).'},422);
  const grants=await ensureLegacySkills(env,user.uid);
  if(!ids.every(id=>grants.some(g=>g.card_id===id&&g.skill_version===SKILL_VERSION&&
    validSkillForCard(g.skill_id,Number(id.split(':')[1])))))
   return json({error:'Deck contains an unverified card. Summon online or choose a verified card.'},422);
  const write=await deckQuery(env,()=>revision===0
   ? env.DB.prepare('INSERT INTO pvp_decks(uid,cards_json,updated_at,revision) VALUES(?,?,?,1) ON CONFLICT(uid) DO NOTHING').bind(user.uid,JSON.stringify(ids),Date.now()).run()
   : env.DB.prepare('UPDATE pvp_decks SET cards_json=?,updated_at=?,revision=revision+1 WHERE uid=? AND revision=?').bind(JSON.stringify(ids),Date.now(),user.uid,revision).run());
  if(write.meta?.changes!==1){
   const latest=await env.DB.prepare('SELECT cards_json,revision FROM pvp_decks WHERE uid=?').bind(user.uid).first();
   return json({error:'Deck changed on another device',cards:latest?JSON.parse(latest.cards_json):[],revision:latest?.revision??0},409);
  }
  return json({cards:ids,revision:revision+1});
 }catch(e){return failure(e)}
}

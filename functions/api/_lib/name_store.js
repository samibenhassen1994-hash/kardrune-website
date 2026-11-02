import {validatePlayerName} from './name_policy.js';
// Names are keyed to Firebase UID, not to a device or browser save.
// This small table is created lazily, so existing D1 deployments need no manual migration.
export async function ensureNameChoices(env){
 await env.DB.prepare(`CREATE TABLE IF NOT EXISTS player_name_choices (
  uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
  name TEXT NOT NULL,
  chosen_at INTEGER NOT NULL
 )`).run();
}

export function normalizeDisplayName(raw){
 return validatePlayerName(raw).name;
}

export async function chosenNameFor(env,uid){
 try{
  const row=await env.DB.prepare('SELECT name FROM player_name_choices WHERE uid=?').bind(uid).first();
  return typeof row?.name==='string'?row.name:null;
 }catch(error){
  // Older D1 instances may not have received a /me request yet.
  if(/no such table:\s*(?:main\.)?player_name_choices/i.test(String(error)))return null;
  throw error;
 }
}

export async function chooseNameOnce(env,uid,name){
 await ensureNameChoices(env);
 const inserted=await env.DB.prepare('INSERT OR IGNORE INTO player_name_choices(uid,name,chosen_at) VALUES(?,?,?)')
  .bind(uid,name,Date.now()).run();
 const chosen=await chosenNameFor(env,uid);
 if(inserted.meta?.changes!==1)return {chosen:false,name:chosen};
 // Keep both the public PvP identity and old serialized save consistent.
 // The revision bump forces devices with stale saves to reload safely.
 await env.DB.batch([
  env.DB.prepare('UPDATE players SET display_name=?,updated_at=CURRENT_TIMESTAMP WHERE uid=?')
   .bind(chosen,uid),
  env.DB.prepare(`UPDATE demo_saves
   SET save_json=json_set(save_json,'$.name',?),revision=revision+1,updated_at=CURRENT_TIMESTAMP
   WHERE uid=? AND json_extract(save_json,'$.name') IS NOT ?`)
   .bind(chosen,uid,chosen),
 ]);
 return {chosen:true,name:chosen};
}

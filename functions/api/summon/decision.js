import {userFromRequest,failure,json} from '../_lib/auth.js';
import {ensureLegacySkills,mergeGrantedSave,currentAccount} from '../_lib/skill_store.js';
import {SKILL_BY_ID,SKILL_VERSION} from '../../../shared/skill_catalog.js';
import {requireActiveAccount} from '../_lib/account_status.js';

export async function onRequestPost({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  await requireActiveAccount(env,user.uid);
  const body=await request.json();
  if(typeof body.rollId!=='string'||typeof body.replace!=='boolean'||
   !Number.isSafeInteger(body.revision)||body.revision<1)return json({error:'Invalid duplicate decision'},400);
  const roll=await env.DB.prepare('SELECT state,result_json,decision_json FROM summon_rolls WHERE uid=? AND roll_id=?')
   .bind(user.uid,body.rollId).first();
  if(!roll)return json({error:'Summon not found'},404);
  if(roll.state==='decided'){
   const snapshot=await currentAccount(env,user.uid);
   if(!snapshot)return json({error:'Verified progress unavailable'},503);
   return json({...JSON.parse(roll.decision_json).response,...snapshot});
  }
  if(roll.state!=='pending')return json({error:'No duplicate is pending'},409);
  const row=await env.DB.prepare('SELECT save_json,revision FROM demo_saves WHERE uid=?').bind(user.uid).first();
  if(!row||row.revision!==body.revision)return json({error:'Save conflict',revision:row?.revision||0},409);
  const grants=await ensureLegacySkills(env,user.uid);
  const save=mergeGrantedSave(JSON.parse(row.save_json),grants);
  const wallet=await env.DB.prepare('SELECT shards FROM skill_wallets WHERE uid=?').bind(user.uid).first();
  if(!wallet)return json({error:'Verified wallet unavailable'},503);
  save.shards=wallet.shards;
  const pending=save.pendingDuplicate;
  if(pending?.rollId!==body.rollId||!SKILL_BY_ID[pending.skillId]||
   !save.owned.includes(pending.id))return json({error:'Pending duplicate mismatch'},409);
  if(body.replace){
   save.attacks[pending.id]=pending.attack;
   save.crits[pending.id]=pending.crit;
   save.skills[pending.id]={id:pending.skillId,rarity:SKILL_BY_ID[pending.skillId].rarity,v:SKILL_VERSION};
  }else save.shards+=100;
  save.pendingDuplicate=null;
  const response={revision:row.revision+1,save,rollId:body.rollId,replaced:body.replace};
  const statements=[
   env.DB.prepare("UPDATE summon_rolls SET state='decided',decision_json=? WHERE uid=? AND roll_id=? AND state='pending'")
    .bind(JSON.stringify({revision:row.revision,response}),user.uid,body.rollId),
   env.DB.prepare('UPDATE demo_saves SET save_json=?,revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=? AND revision=?')
    .bind(JSON.stringify(save),user.uid,row.revision),
  ];
  if(!body.replace)statements.push(env.DB.prepare('UPDATE skill_wallets SET shards=shards+100,updated_at=? WHERE uid=?')
   .bind(Date.now(),user.uid));
  if(body.replace)statements.push(env.DB.prepare(`INSERT INTO skill_grants
   (uid,card_id,attack,crit,skill_id,rarity,skill_version,source,roll_id,updated_at)
   VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(uid,card_id) DO UPDATE SET
   attack=excluded.attack,crit=excluded.crit,skill_id=excluded.skill_id,
   rarity=excluded.rarity,skill_version=excluded.skill_version,
   source=excluded.source,roll_id=excluded.roll_id,updated_at=excluded.updated_at`)
   .bind(user.uid,pending.id,pending.attack,pending.crit,pending.skillId,
    SKILL_BY_ID[pending.skillId].rarity,SKILL_VERSION,'summon',body.rollId,Date.now()));
  await env.DB.batch(statements);
  return json(response);
 }catch(error){
  if(String(error).includes('revision conflict')||String(error).includes('UNIQUE constraint'))
   return json({error:'Save conflict'},409);
  return failure(error);
 }
}

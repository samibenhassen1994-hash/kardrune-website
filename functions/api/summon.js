import {userFromRequest,failure,json} from './_lib/auth.js';
import {ensureLegacySkills,mergeGrantedSave,rollCard,currentAccount} from './_lib/skill_store.js';
import {SKILL_VERSION} from '../../shared/skill_catalog.js';
import {requireActiveAccount} from './_lib/account_status.js';

const rollPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const freeWindowMs=12*60*60*1000;

async function freeStatus(env,uid,now=Date.now()){
 const rows=await env.DB.prepare(`SELECT created_at FROM summon_rolls
  WHERE uid=? AND created_at>? AND json_extract(result_json,'$.cost')=0
  ORDER BY created_at`).bind(uid,now-freeWindowMs).all();
 const used=(rows.results||[]).map(row=>Number(row.created_at));
 return {available:Math.max(0,2-used.length),nextAt:used.length?used[0]+freeWindowMs:null,serverNow:now};
}

export async function onRequestGet({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  await requireActiveAccount(env,user.uid);
  return json(await freeStatus(env,user.uid));
 }catch(error){return failure(error)}
}

export async function onRequestPost({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  await requireActiveAccount(env,user.uid);
  const body=await request.json();
  if(typeof body.featured!=='boolean'||(body.free!==undefined&&typeof body.free!=='boolean')||
    (body.free===true&&body.featured)||!Number.isSafeInteger(body.revision)||body.revision<1||
    typeof body.rollId!=='string'||!rollPattern.test(body.rollId))return json({error:'Invalid summon request'},400);
  const old=await env.DB.prepare('SELECT state,result_json,decision_json FROM summon_rolls WHERE uid=? AND roll_id=?')
   .bind(user.uid,body.rollId).first();
  if(old){
   const snapshot=await currentAccount(env,user.uid);
   if(!snapshot)return json({error:'Verified progress unavailable'},503);
   const original=old.state==='decided'?JSON.parse(old.decision_json).response:JSON.parse(old.result_json);
   return json({...original,...snapshot});
  }
  const row=await env.DB.prepare('SELECT save_json,revision FROM demo_saves WHERE uid=?').bind(user.uid).first();
  if(!row)return json({error:'Create a cloud save before summoning'},409);
  if(row.revision!==body.revision)return json({error:'Save conflict',revision:row.revision},409);
  const grants=await ensureLegacySkills(env,user.uid);
  const save=mergeGrantedSave(JSON.parse(row.save_json),grants);
  if(save.pendingDuplicate?.rollId)return json({error:'Resolve the pending duplicate first'},409);
  const cost=body.free===true?0:body.featured?600:300;
  if(body.free===true&&(await freeStatus(env,user.uid)).available<1)
   return json({error:'Free summons are recharging'},429);
  const wallet=await env.DB.prepare('SELECT shards FROM skill_wallets WHERE uid=?').bind(user.uid).first();
  if(!wallet||wallet.shards<cost)return json({error:'Not enough verified Shards'},400);
  save.shards=wallet.shards;
  const card=rollCard(body.featured),duplicate=save.owned.includes(card.id);
  save.shards-=cost;
  save.pulls=(Number.isSafeInteger(save.pulls)?save.pulls:0)+1;
  if(duplicate){
   save.pendingDuplicate={id:card.id,attack:card.attack,crit:card.crit,
    skillId:card.skill.id,skillVersion:SKILL_VERSION,rollId:body.rollId};
  }else{
   save.owned=[...save.owned,card.id];
   save.attacks[card.id]=card.attack;
   save.crits[card.id]=card.crit;
   save.skills[card.id]={id:card.skill.id,rarity:card.skill.rarity,v:SKILL_VERSION};
  }
  const response={revision:row.revision+1,save,card:{id:card.id,attack:card.attack,
   crit:card.crit,skillId:card.skill.id},duplicate,rollId:body.rollId,cost};
  const statements=[
   env.DB.prepare('INSERT INTO summon_rolls(uid,roll_id,base_revision,state,result_json,created_at) VALUES(?,?,?,?,?,?)')
    .bind(user.uid,body.rollId,row.revision,duplicate?'pending':'applied',JSON.stringify(response),Date.now()),
   env.DB.prepare('UPDATE skill_wallets SET shards=shards-?,updated_at=? WHERE uid=? AND shards>=?')
    .bind(cost,Date.now(),user.uid,cost),
   env.DB.prepare('UPDATE demo_saves SET save_json=?,revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=? AND revision=?')
    .bind(JSON.stringify(save),user.uid,row.revision),
  ];
  if(!duplicate)statements.push(env.DB.prepare(`INSERT INTO skill_grants
   (uid,card_id,attack,crit,skill_id,rarity,skill_version,source,roll_id,updated_at)
   VALUES(?,?,?,?,?,?,?,?,?,?)`).bind(user.uid,card.id,card.attack,card.crit,
    card.skill.id,card.skill.rarity,SKILL_VERSION,'summon',body.rollId,Date.now()));
  await env.DB.batch(statements);
  return json(response);
 }catch(error){
  if(String(error).includes('revision conflict')||String(error).includes('UNIQUE constraint'))
   return json({error:'Save conflict'},409);
  return failure(error);
 }
}

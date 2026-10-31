import {userFromRequest,failure,json} from './_lib/auth.js';
import {secureInt,ensureLegacySkills,mergeGrantedSave,currentAccount} from './_lib/skill_store.js';
import {effectiveCardStats} from '../../shared/card_stat_limits.js';

const rollPattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const today=()=>new Date().toLocaleDateString('sv-SE',{timeZone:'Europe/Rome'});

export async function onRequestPost({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  const body=await request.json();
  if(typeof body.rollId!=='string'||!rollPattern.test(body.rollId)||
   !Number.isSafeInteger(body.revision)||body.revision<1)return json({error:'Invalid practice request'},400);
  const previous=await env.DB.prepare('SELECT result_json FROM practice_rolls WHERE uid=? AND roll_id=?')
   .bind(user.uid,body.rollId).first();
  if(previous){
   const snapshot=await currentAccount(env,user.uid);
   if(!snapshot)return json({error:'Verified progress unavailable'},503);
   return json({...JSON.parse(previous.result_json),...snapshot});
  }
  const row=await env.DB.prepare('SELECT save_json,revision FROM demo_saves WHERE uid=?').bind(user.uid).first();
  if(!row||row.revision!==body.revision)return json({error:'Save conflict',revision:row?.revision||0},409);
  const daily=await env.DB.prepare('SELECT day,count FROM practice_daily WHERE uid=?').bind(user.uid).first();
  const wallet=await env.DB.prepare('SELECT shards FROM skill_wallets WHERE uid=?').bind(user.uid).first();
  if(!daily||!wallet)return json({error:'Verified progress unavailable'},503);
  const grants=await ensureLegacySkills(env,user.uid);
  const save=mergeGrantedSave(JSON.parse(row.save_json),grants);
  const active=save.active,grant=grants.find(g=>g.card_id===active);
  if(!grant)return json({error:'Select a verified card to practice online'},409);
  const stage=Number(active.split(':')[1]);
  const effective=effectiveCardStats(stage,grant.attack,grant.crit);
  const chance=Math.max(.05,Math.min(.90,.43+(effective.attack+(stage-1)*18)/200));
  const win=secureInt(1000000000)/1000000000<chance;
  const day=today(),count=daily.day===day?daily.count:0,reward=count<10?(win?100:35):0;
  save.shards=wallet.shards+reward;
  save.practiceDaily={day,count:count+(reward>0?1:0)};
  save.duels=(Number.isSafeInteger(save.duels)?save.duels:0)+1;
  if(win)save.wins=(Number.isSafeInteger(save.wins)?save.wins:0)+1;
  const response={revision:row.revision+1,save,win,reward,chance,rollId:body.rollId};
  const statements=[
   env.DB.prepare('INSERT INTO practice_rolls(uid,roll_id,base_revision,result_json) VALUES(?,?,?,?)')
    .bind(user.uid,body.rollId,row.revision,JSON.stringify(response)),
   env.DB.prepare('UPDATE demo_saves SET save_json=?,revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=? AND revision=?')
    .bind(JSON.stringify(save),user.uid,row.revision),
   env.DB.prepare('UPDATE practice_daily SET day=?,count=? WHERE uid=?')
    .bind(day,save.practiceDaily.count,user.uid),
  ];
  if(reward>0){
   statements.push(env.DB.prepare('UPDATE skill_wallets SET shards=shards+?,updated_at=? WHERE uid=?')
    .bind(reward,Date.now(),user.uid));
   statements.push(env.DB.prepare('INSERT INTO currency_ledger(id,uid,delta,reason) VALUES(?,?,?,?)')
    .bind(`practice:${user.uid}:${body.rollId}`,user.uid,reward,'practice'));
  }
  await env.DB.batch(statements);
  return json(response);
 }catch(error){
  if(String(error).includes('revision conflict')||String(error).includes('UNIQUE constraint'))
   return json({error:'Save conflict'},409);
  return failure(error);
 }
}

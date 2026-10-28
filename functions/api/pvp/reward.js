import {userFromRequest,failure,json} from '../_lib/auth.js';
import {ensureLegacySkills,mergeGrantedSave,currentAccount} from '../_lib/skill_store.js';

export async function onRequestPost({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  const body=await request.json();
  if(typeof body.matchId!=='string'||! /^[0-9a-f-]{36}$/i.test(body.matchId)||
   !Number.isSafeInteger(body.revision)||body.revision<1)return json({error:'Invalid reward request'},400);
  const previous=await env.DB.prepare('SELECT response_json FROM pvp_reward_claims WHERE uid=? AND match_id=?')
   .bind(user.uid,body.matchId).first();
  if(previous){
   const snapshot=await currentAccount(env,user.uid);
   if(!snapshot)return json({error:'Verified progress unavailable'},503);
   return json({...JSON.parse(previous.response_json),...snapshot});
  }
  const history=await env.DB.prepare('SELECT player_a,player_b,reason FROM pvp_live_history WHERE id=?')
   .bind(body.matchId).first();
  if(!history)return json({error:'Match result pending'},404);
  if(history.reason!=='completed'||![history.player_a,history.player_b].includes(user.uid))
   return json({error:'Match reward unavailable'},403);
  const row=await env.DB.prepare('SELECT save_json,revision FROM demo_saves WHERE uid=?').bind(user.uid).first();
  if(!row||row.revision!==body.revision)return json({error:'Save conflict',revision:row?.revision||0},409);
  const wallet=await env.DB.prepare('SELECT shards FROM skill_wallets WHERE uid=?').bind(user.uid).first();
  if(!wallet)return json({error:'Verified wallet unavailable'},503);
  const grants=await ensureLegacySkills(env,user.uid);
  const save=mergeGrantedSave(JSON.parse(row.save_json),grants);
  save.shards=wallet.shards+100;
  const response={revision:row.revision+1,save,reward:100,matchId:body.matchId};
  await env.DB.batch([
   env.DB.prepare('INSERT INTO pvp_reward_claims(uid,match_id,base_revision,response_json) VALUES(?,?,?,?)')
    .bind(user.uid,body.matchId,row.revision,JSON.stringify(response)),
   env.DB.prepare('UPDATE demo_saves SET save_json=?,revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=? AND revision=?')
    .bind(JSON.stringify(save),user.uid,row.revision),
   env.DB.prepare('UPDATE skill_wallets SET shards=shards+100,updated_at=? WHERE uid=?')
    .bind(Date.now(),user.uid),
   env.DB.prepare('INSERT INTO currency_ledger(id,uid,delta,reason) VALUES(?,?,100,?)')
    .bind(`pvp:${user.uid}:${body.matchId}`,user.uid,'pvp_friendly'),
  ]);
  return json(response);
 }catch(error){
  if(String(error).includes('revision conflict')||String(error).includes('UNIQUE constraint'))
   return json({error:'Save conflict'},409);
  return failure(error);
 }
}

import {userFromRequest,failure,json} from './_lib/auth.js';
import {requireActiveAccount} from './_lib/account_status.js';
import {chooseNameOnce} from './_lib/name_store.js';
import {validatePlayerName} from './_lib/name_policy.js';

export async function onRequestPost({request,env}){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  const raw=await request.text();
  if(raw.length>512)return json({error:'Invalid display name'},400);
  let data;try{data=JSON.parse(raw)}catch{return json({error:'Invalid JSON'},400)}
  const validation=validatePlayerName(data?.name);
  if(!validation.name)return json({error:'Invalid player name',code:'INVALID_PLAYER_NAME',reason:validation.reason},400);
  const name=validation.name;
  await env.DB.prepare('INSERT OR IGNORE INTO players(uid,display_name) VALUES(?,?)')
    .bind(user.uid,user.name).run();
  await requireActiveAccount(env,user.uid);
  const result=await chooseNameOnce(env,user.uid,name);
  if(!result.chosen)return json({error:'Display name already chosen',name:result.name,chosen:true},409);
  return json(result);
 }catch(error){return failure(error)}
}

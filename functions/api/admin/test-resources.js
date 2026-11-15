import {userFromRequest,failure,json} from '../_lib/auth.js';
import {requireActiveAccount} from '../_lib/account_status.js';
import {requireAdmin} from '../portal/_lib.js';
import {currentAccount} from '../_lib/skill_store.js';
async function authorized(request,env){
 const user=await userFromRequest(request,env);
 if(!env.DB)throw json({error:'Database unavailable'},503);
 await requireActiveAccount(env,user.uid);await requireAdmin(env,user.uid);
 return user.uid;
}
export async function onRequestGet({request,env}){
 try{const uid=await authorized(request,env);
  const ready=await env.DB.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='admin_test_resource_grants'").first();
  return json({admin:true,enabled:!!ready,uid});
 }catch(e){return failure(e)}
}
export async function onRequestPost({request,env}){
 try{const uid=await authorized(request,env),b=await request.json();
  if(!b||Object.hasOwn(b,'uid')||typeof b.requestId!=='string'||!/^[a-f0-9]{32}$/.test(b.requestId)||
   !Number.isSafeInteger(b.revision)||b.revision<1||!Number.isSafeInteger(b.shards)||b.shards<0||b.shards>100000||
   !Number.isSafeInteger(b.keysEach)||b.keysEach<0||b.keysEach>1000||b.shards+b.keysEach===0)return json({error:'Invalid test grant'},400);
  const old=await env.DB.prepare('SELECT shards,keys_each FROM admin_test_resource_grants WHERE uid=? AND request_id=?').bind(uid,b.requestId).first();
  if(old&&(old.shards!==b.shards||old.keys_each!==b.keysEach))return json({error:'Request already used'},409);
  if(!old)await env.DB.prepare('INSERT INTO admin_test_resource_grants(uid,request_id,base_revision,shards,keys_each,created_at) VALUES(?,?,?,?,?,?)')
   .bind(uid,b.requestId,b.revision,b.shards,b.keysEach,Date.now()).run();
  return json({...await currentAccount(env,uid),granted:true});
 }catch(e){
  if(/ADMIN_CONFLICT|UNIQUE constraint/.test(String(e)))return json({error:'Save conflict; refresh and retry'},409);
  if(/no such table/.test(String(e)))return json({error:'Admin tools require migration 0017'},503);
  return failure(e);
 }
}

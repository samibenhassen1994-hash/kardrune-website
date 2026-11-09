import {context,json,failure} from './_lib/pvp.js';
import {forgeState,forgeAttempt,forgeDecision} from './_lib/forge.js';
import {currentAccount} from './_lib/skill_store.js';
function fail(error){
 const message=String(error?.message||error);
 if(/no such table|no such column/.test(message))return json({error:'FORGE_UNAVAILABLE'},503);
 for(const code of ['FORGE_PENDING','FORGE_INVALID','FORGE_CARD','FORGE_CAP','FORGE_KEYS','FORGE_DUPLICATE','FORGE_CONFLICT','FORGE_BANNED'])
 if(message.includes(code))return json({error:code},code==='FORGE_BANNED'?403:422);
 return failure(error);
}
export async function onRequestGet({request,env}){
 try{const {uid}=await context(request,env);return json({...await forgeState(env,uid),...await currentAccount(env,uid)});}catch(error){return fail(error);}
}
export async function onRequestPost({request,env}){
 try{
 const {uid}=await context(request,env);
 const raw=await request.text();if(raw.length>1024)return json({error:'FORGE_INVALID'},413);
 let body;try{body=JSON.parse(raw)}catch{return json({error:'FORGE_INVALID'},400);}
 const result=body?.action==='decision'?await forgeDecision(env,uid,body):await forgeAttempt(env,uid,body);
 const snapshot=await currentAccount(env,uid);
 return json({result,...await forgeState(env,uid),...snapshot});
 }catch(error){return fail(error);}
}

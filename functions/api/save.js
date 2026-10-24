import {userFromRequest,failure,json} from './_lib/auth.js';
const allowed=new Set(['sam','lira','rhea','dren','tor','aria','kael','neris','nyra']);
function validSave(v){
 if(!v||typeof v!=='object'||Array.isArray(v))return false;
 if(!Array.isArray(v.owned)||v.owned.length>27||v.owned.length===0||!v.owned.every(x=>typeof x==='string'&&allowed.has(x.split(':')[0])&&/^[a-z]+:[123]$/.test(x)))return false;
 if(!Number.isSafeInteger(v.shards)||v.shards<0||v.shards>999999999)return false;
 if(!v.attacks||!v.crits||typeof v.attacks!=='object'||typeof v.crits!=='object')return false;
 if(!v.owned.every(id=>Number.isInteger(v.attacks[id])&&v.attacks[id]>=1&&v.attacks[id]<=100&&Number.isInteger(v.crits[id])&&v.crits[id]>=0&&v.crits[id]<=25))return false;
 return typeof v.name==='string'&&v.name.length<=20;
}
async function handle({request,env},write){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  if(!write){
   const row=await env.DB.prepare('SELECT save_json,revision,updated_at FROM demo_saves WHERE uid=?').bind(user.uid).first();
   return json(row?{save:JSON.parse(row.save_json),revision:row.revision,updatedAt:row.updated_at}:{save:null,revision:0});
  }
  const raw=await request.text();if(raw.length>12000)return json({error:'Save too large'},413);
  let input;try{input=JSON.parse(raw)}catch{return json({error:'Malformed JSON'},400)}
  if(!validSave(input.save)||!Number.isSafeInteger(input.revision)||input.revision<0)return json({error:'Invalid demo save'},400);
  const existing=await env.DB.prepare('SELECT revision FROM demo_saves WHERE uid=?').bind(user.uid).first();
  const current=existing?.revision||0;
  if(input.revision!==current)return json({error:'Save conflict',revision:current},409);
  await env.DB.prepare('INSERT OR IGNORE INTO players (uid,display_name) VALUES (?,?)').bind(user.uid,user.name).run();
  const result=await env.DB.prepare(`INSERT INTO demo_saves(uid,save_json,revision) VALUES (?,?,1)
   ON CONFLICT(uid) DO UPDATE SET save_json=excluded.save_json,revision=demo_saves.revision+1,updated_at=CURRENT_TIMESTAMP
   WHERE demo_saves.revision=?`).bind(user.uid,JSON.stringify(input.save),input.revision).run();
  if(result.meta?.changes!==1)return json({error:'Save conflict'},409);
  return json({revision:current+1,saved:true,competitive:false});
 }catch(e){return failure(e)}
}
export const onRequestGet=ctx=>handle(ctx,false);
export const onRequestPut=ctx=>handle(ctx,true);

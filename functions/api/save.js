import {userFromRequest,failure,json} from './_lib/auth.js';
import {ensureLegacySkills,mergeGrantedSave,rollSkill} from './_lib/skill_store.js';
import {SKILL_VERSION} from '../../shared/skill_catalog.js';
const allowed=new Set(['sam','lira','rhea','dren','tor','aria','kael','neris','nyra']);
function validSave(v){
 if(!v||typeof v!=='object'||Array.isArray(v))return false;
 if(!Array.isArray(v.owned)||v.owned.length>27||v.owned.length===0||!v.owned.every(x=>typeof x==='string'&&allowed.has(x.split(':')[0])&&/^[a-z]+:[123]$/.test(x)))return false;
 if(!Number.isSafeInteger(v.shards)||v.shards<0||v.shards>999999999)return false;
 if(!v.attacks||!v.crits||typeof v.attacks!=='object'||typeof v.crits!=='object'||
  !v.skills||typeof v.skills!=='object'||Array.isArray(v.skills))return false;
 if(!v.owned.every(id=>Number.isInteger(v.attacks[id])&&v.attacks[id]>=1&&v.attacks[id]<=100&&Number.isInteger(v.crits[id])&&v.crits[id]>=0&&v.crits[id]<=25))return false;
 return typeof v.name==='string'&&v.name.length<=20;
}
async function handle({request,env},write){
 try{
  const user=await userFromRequest(request,env);
  if(!env.DB)return json({error:'D1 not configured'},503);
  if(!write){
   const row=await env.DB.prepare('SELECT save_json,revision,updated_at FROM demo_saves WHERE uid=?').bind(user.uid).first();
   if(!row)return json({save:null,revision:0});
   const grants=await ensureLegacySkills(env,user.uid);
   const wallet=await env.DB.prepare('SELECT shards FROM skill_wallets WHERE uid=?').bind(user.uid).first();
   const daily=await env.DB.prepare('SELECT day,count FROM practice_daily WHERE uid=?').bind(user.uid).first();
   if(!wallet||!daily)return json({error:'Verified progress unavailable'},503);
   const save=mergeGrantedSave(JSON.parse(row.save_json),grants);
   save.shards=wallet.shards;
   save.practiceDaily={day:daily.day,count:daily.count};
   return json({save,revision:row.revision,updatedAt:row.updated_at});
  }
  const raw=await request.text();if(raw.length>12000)return json({error:'Save too large'},413);
  let input;try{input=JSON.parse(raw)}catch{return json({error:'Malformed JSON'},400)}
  if(!input?.save||!Object.hasOwn(input.save,'skills'))
   return json({error:'Update Idle KardRune before saving online'},426);
  if(!validSave(input.save)||!Number.isSafeInteger(input.revision)||input.revision<0)return json({error:'Invalid demo save'},400);
  const existing=await env.DB.prepare('SELECT revision,save_json FROM demo_saves WHERE uid=?').bind(user.uid).first();
  const current=existing?.revision||0;
  if(input.revision!==current)return json({error:'Save conflict',revision:current},409);
  const grants=existing?await ensureLegacySkills(env,user.uid):[];
  if(!existing&&input.save.owned.includes('sam:1')){
   const skill=rollSkill(1);
   grants.push({card_id:'sam:1',attack:40,crit:4,skill_id:skill.id,
    rarity:skill.rarity,skill_version:SKILL_VERSION,source:'initial'});
  }
  const previous=existing?JSON.parse(existing.save_json):null;
  const pending=previous?.pendingDuplicate?.rollId?previous.pendingDuplicate:
   input.save.pendingDuplicate?.rollId?null:input.save.pendingDuplicate??null;
  const normalized=mergeGrantedSave(input.save,grants,pending);
  const wallet=existing?await env.DB.prepare('SELECT shards FROM skill_wallets WHERE uid=?').bind(user.uid).first():null;
  const daily=existing?await env.DB.prepare('SELECT day,count FROM practice_daily WHERE uid=?').bind(user.uid).first():null;
  if(existing&&(!wallet||!daily))return json({error:'Verified progress unavailable'},503);
  normalized.shards=wallet?.shards??1500;
  normalized.practiceDaily=daily?{day:daily.day,count:daily.count}:{day:'',count:0};
  await env.DB.prepare('INSERT OR IGNORE INTO players (uid,display_name) VALUES (?,?)').bind(user.uid,user.name).run();
  const write=env.DB.prepare(`INSERT INTO demo_saves(uid,save_json,revision) VALUES (?,?,1)
   ON CONFLICT(uid) DO UPDATE SET save_json=excluded.save_json,revision=demo_saves.revision+1,updated_at=CURRENT_TIMESTAMP
   WHERE demo_saves.revision=?`).bind(user.uid,JSON.stringify(normalized),input.revision);
  let result;
  if(!existing){
   const statements=[write,
    env.DB.prepare('INSERT INTO skill_wallets(uid,shards,updated_at) VALUES(?,?,?)')
     .bind(user.uid,1500,Date.now()),
    env.DB.prepare('INSERT INTO practice_daily(uid,day,count) VALUES(?,?,0)')
     .bind(user.uid,'')];
   if(grants.length){const grant=grants[0];statements.push(env.DB.prepare(`INSERT INTO skill_grants
     (uid,card_id,attack,crit,skill_id,rarity,skill_version,source,roll_id,updated_at)
     VALUES(?,?,?,?,?,?,?,?,?,?)`).bind(user.uid,grant.card_id,grant.attack,grant.crit,
      grant.skill_id,grant.rarity,SKILL_VERSION,'initial',null,Date.now()));}
   [result]=await env.DB.batch(statements);
  }else result=await write.run();
  if(result.meta?.changes!==1)return json({error:'Save conflict'},409);
  return json({revision:current+1,saved:true,competitive:false,save:normalized});
 }catch(e){return failure(e)}
}
export const onRequestGet=ctx=>handle(ctx,false);
export const onRequestPut=ctx=>handle(ctx,true);

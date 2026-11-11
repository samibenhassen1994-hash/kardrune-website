import {secureInt,grantsFor} from './skill_store.js';
import {CARD_STAT_LIMITS,effectiveCardStats} from '../../../shared/card_stat_limits.js';
import {SKILLS,SKILL_WEIGHTS,RARITIES,SKILL_VERSION,validSkillForStage} from '../../../shared/skill_catalog.js';
export const FORGE_CHANCES=Object.freeze({green:35,blue:55,red:75});
export const FORGE_INCREMENTS=Object.freeze({ATK:{min:1,max:5},CRT:{min:1,max:2}});
export function forgeOutcome(card,color,stat,range=FORGE_INCREMENTS[stat],random=secureInt){
 const stage=Number(card.card_id.split(':')[1]),limits=CARD_STAT_LIMITS[stage];
 if(!limits||!Object.hasOwn(FORGE_CHANCES,color)||!['ATK','CRT','SKILL'].includes(stat)||!validSkillForStage(card.skill_id,stage))throw new Error('FORGE_INVALID');
 const before={attack:card.attack,crit:card.crit,skillId:card.skill_id,rarity:card.rarity,v:SKILL_VERSION};
 const after={...before};
 const field=stat==='ATK'?'attack':'crit';
 if(stat!=='SKILL'&&before[field]>=limits[field][1])throw new Error('FORGE_CAP');
 const success=random(100)<FORGE_CHANCES[color];
 if(success){
  if(stat==='SKILL'){
   let ticket=random(1000),rarity=0;const weights=SKILL_WEIGHTS[stage];
   while(ticket>=weights[rarity])ticket-=weights[rarity++];
   const choices=SKILLS.filter(s=>s.rarity===RARITIES[rarity]&&!s.id.startsWith('D')&&s.id!==card.skill_id);
   const skill=choices[random(choices.length)];after.skillId=skill.id;after.rarity=skill.rarity;
  }else{
   after[field]=Math.min(limits[field][1],effectiveCardStats(stage,card.attack,card.crit)[field]+range.min+random(range.max-range.min+1));
  }
 }
 return {success,before,after};
}
const present=r=>r.pendingSkill?{...r,after:r.proposed}:r;
export async function forgeState(env,uid){
 // Probe migration before any other work; missing schema fails closed.
 const inventory=await env.DB.prepare('SELECT color,quantity FROM forge_keys WHERE uid=?').bind(uid).all();
 const save=await env.DB.prepare('SELECT save_json,revision FROM demo_saves WHERE uid=?').bind(uid).first();
 const owned=save?JSON.parse(save.save_json).owned:[];
 const pending=await env.DB.prepare(`SELECT a.result_json FROM forge_attempts a LEFT JOIN forge_skill_decisions d ON d.uid=a.uid AND d.request_id=a.request_id WHERE a.uid=? AND json_extract(a.result_json,'$.pendingSkill')=1 AND d.request_id IS NULL LIMIT 1`).bind(uid).first();
 const grants=await grantsFor(env,uid);
 return {pendingSkill:pending?present(JSON.parse(pending.result_json)):null,revision:save?.revision??0,keys:Object.fromEntries(['green','blue','red'].map(c=>[c,inventory.results.find(r=>r.color===c)?.quantity??0])),
 chances:FORGE_CHANCES,increments:FORGE_INCREMENTS,cards:grants.filter(c=>owned.includes(c.card_id)&&!['zeus','poseidon','hades','athena','ares','apollo'].includes(c.card_id.split(':')[0])&&validSkillForStage(c.skill_id,Number(c.card_id.split(':')[1]))).map(c=>({id:c.card_id,...effectiveCardStats(Number(c.card_id.split(':')[1]),c.attack,c.crit),skillId:c.skill_id})),caps:CARD_STAT_LIMITS};
}
export async function forgeAttempt(env,uid,body,random=secureInt){
 if(!body||typeof body.requestId!=='string'||!/^[-a-f0-9]{32,36}$/.test(body.requestId)||typeof body.cardId!=='string'||!/^(sam|lira|rhea|dren|tor|aria|kael|neris|nyra):[123]$/.test(body.cardId)||!Object.hasOwn(FORGE_CHANCES,body.color)||!['ATK','CRT','SKILL'].includes(body.stat)||!Number.isSafeInteger(body.revision)||body.revision<1)throw new Error('FORGE_INVALID');
 const payload=JSON.stringify({cardId:body.cardId,color:body.color,stat:body.stat});
 const receipt=()=>env.DB.prepare('SELECT payload,result_json FROM forge_attempts WHERE uid=? AND request_id=?').bind(uid,body.requestId).first();
 const replay=old=>{if(old.payload!==payload)throw new Error('FORGE_INVALID');return present(JSON.parse(old.result_json));};
 const old=await receipt();if(old)return replay(old);
 const card=await env.DB.prepare('SELECT * FROM skill_grants WHERE uid=? AND card_id=?').bind(uid,body.cardId).first();
 if(!card)throw new Error('FORGE_CARD');
 const result=forgeOutcome(card,body.color,body.stat,FORGE_INCREMENTS[body.stat],random);
 if(body.stat==='SKILL'&&result.success){
  await env.DB.prepare('SELECT request_id FROM forge_skill_decisions WHERE uid=? LIMIT 1').bind(uid).first();
  result.proposed=result.after;result.after={...result.before};result.pendingSkill=true;
  result.requestId=body.requestId;result.cardId=body.cardId;
 }
 try{
 await env.DB.prepare(`INSERT INTO forge_attempts(uid,request_id,card_id,color,stat,base_revision,payload,result_json,created_at) VALUES(?,?,?,?,?,?,?,?,?)`)
 .bind(uid,body.requestId,body.cardId,body.color,body.stat,body.revision,payload,JSON.stringify(result),Date.now()).run();
 }catch(error){const old=await receipt();if(old)return replay(old);throw error;}
 return present(result);
}

export async function forgeDecision(env,uid,body){
 if(typeof body.requestId!=='string'||!/^[-a-f0-9]{32,36}$/.test(body.requestId)||typeof body.accept!=='boolean'||!Number.isSafeInteger(body.revision)||body.revision<1)throw new Error('FORGE_INVALID');
 const receipt=()=>env.DB.prepare('SELECT accept FROM forge_skill_decisions WHERE uid=? AND request_id=?').bind(uid,body.requestId).first();
 const existing=await receipt();if(existing)return {accepted:existing.accept===1};
 try{await env.DB.prepare('INSERT INTO forge_skill_decisions(uid,request_id,accept,base_revision,created_at) VALUES(?,?,?,?,?)').bind(uid,body.requestId,body.accept?1:0,body.revision,Date.now()).run();}
 catch(e){const saved=await receipt();if(saved)return {accepted:saved.accept===1};throw e;}
 return {accepted:body.accept};
}

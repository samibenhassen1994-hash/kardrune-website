import {SKILLS,SKILL_BY_ID,SKILL_WEIGHTS,SKILL_VERSION,RARITIES,validSkillForStage} from '../../../shared/skill_catalog.js';

// Rejection sampling avoids modulo bias in server-issued rarity/stat rolls.
export function secureInt(max){
 const limit=Math.floor(0x100000000/max)*max;
 const bytes=new Uint32Array(1);
 do{crypto.getRandomValues(bytes)}while(bytes[0]>=limit);
 return bytes[0]%max;
}
export function rollSkill(stage){
 const weights=SKILL_WEIGHTS[stage];
 if(!weights)throw new RangeError('Invalid Stage');
 let ticket=secureInt(1000),rarity=0;
 while(ticket>=weights[rarity]){ticket-=weights[rarity];rarity++}
 const options=SKILLS.filter(skill=>skill.rarity===RARITIES[rarity]);
 return options[secureInt(5)];
}
export function rollCard(featured){
 const stageTicket=secureInt(100),stage=featured
  ?stageTicket<60?1:stageTicket<90?2:3
  :stageTicket<78?1:stageTicket<97?2:3;
 const heroes=['sam','lira','rhea','dren','tor','aria','kael','neris','nyra'];
 const hero=featured&&secureInt(100)<35?'dren':heroes[secureInt(9)];
 return {id:`${hero}:${stage}`,attack:1+secureInt(100),crit:secureInt(26),skill:rollSkill(stage)};
}
export async function grantsFor(env,uid){
 const rows=await env.DB.prepare('SELECT card_id,attack,crit,skill_id,rarity,skill_version,source FROM skill_grants WHERE uid=?').bind(uid).all();
 return rows.results||[];
}
export async function ensureLegacySkills(env,uid){
 const legacy=await env.DB.prepare('SELECT card_id FROM skill_legacy_cards WHERE uid=?').bind(uid).all();
 const existing=await grantsFor(env,uid);
 for(const row of legacy.results||[]){
  if(existing.some(grant=>grant.card_id===row.card_id)||
    !/^(sam|lira|rhea|dren|tor|aria|kael|neris|nyra):[123]$/.test(row.card_id))continue;
  const hash=[...row.card_id].reduce((h,c)=>Math.imul(h^c.charCodeAt(0),16777619)>>>0,2166136261);
  const attack=25+hash%51,crit=4+hash%12;
  await env.DB.prepare(`INSERT OR IGNORE INTO skill_grants
   (uid,card_id,attack,crit,skill_id,rarity,skill_version,source,roll_id,updated_at)
   VALUES(?,?,?,?,NULL,NULL,?,'legacy',NULL,?)`)
   .bind(uid,row.card_id,attack,crit,SKILL_VERSION,Date.now()).run();
 }
 const grants=await grantsFor(env,uid);
 for(const grant of grants){
  if(grant.skill_id!==null)continue;
  const stage=Number(grant.card_id.split(':')[1]);
  if(!Number.isInteger(stage)||stage<1||stage>3)continue;
  const skill=rollSkill(stage);
  await env.DB.prepare('UPDATE skill_grants SET skill_id=?,rarity=?,skill_version=?,updated_at=? WHERE uid=? AND card_id=? AND skill_id IS NULL')
   .bind(skill.id,skill.rarity,SKILL_VERSION,Date.now(),uid,grant.card_id).run();
 }
 return grantsFor(env,uid);
}
export function mergeGrantedSave(save,grants,serverPending=undefined){
 const next={...save,attacks:{...save.attacks},crits:{...save.crits},skills:{}};
 for(const grant of grants){
  const stage=Number(grant.card_id.split(':')[1]);
  if(!validSkillForStage(grant.skill_id,stage)||grant.skill_version!==SKILL_VERSION)continue;
  if(!next.owned?.includes(grant.card_id))next.owned=[...(next.owned||[]),grant.card_id];
  next.attacks[grant.card_id]=grant.attack;
  next.crits[grant.card_id]=grant.crit;
  next.skills[grant.card_id]={id:grant.skill_id,rarity:SKILL_BY_ID[grant.skill_id].rarity,v:SKILL_VERSION};
 }
 if(serverPending!==undefined)next.pendingDuplicate=serverPending;
 return next;
}
export async function currentAccount(env,uid){
 const row=await env.DB.prepare('SELECT save_json,revision FROM demo_saves WHERE uid=?').bind(uid).first();
 if(!row)return null;
 const grants=await ensureLegacySkills(env,uid);
 const wallet=await env.DB.prepare('SELECT shards FROM skill_wallets WHERE uid=?').bind(uid).first();
 const daily=await env.DB.prepare('SELECT day,count FROM practice_daily WHERE uid=?').bind(uid).first();
 if(!wallet||!daily)return null;
 const save=mergeGrantedSave(JSON.parse(row.save_json),grants);
 save.shards=wallet.shards;
 save.practiceDaily={day:daily.day,count:daily.count};
 return {save,revision:row.revision};
}

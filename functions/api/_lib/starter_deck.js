import {SKILLS,SKILL_VERSION} from '../../../shared/skill_catalog.js';
import {secureInt,mergeGrantedSave,grantsFor} from './skill_store.js';
export const STARTER_IDS=Object.freeze(['sam','lira','rhea','dren','tor','aria','kael','neris','nyra'].map(hero=>`${hero}:1`));
const common=SKILLS.filter(skill=>skill.rarity==='common');
export function starterAdditions(save,grants,random=secureInt){
 const owned=new Set(save.owned||[]),verified=new Set(grants.map(g=>g.card_id));
 const needed=Math.max(0,9-[...owned].filter(id=>verified.has(id)).length);
 return STARTER_IDS.filter(id=>!owned.has(id)&&!verified.has(id)).slice(0,needed).map(id=>{
  const skill=common[random(common.length)];
  return {card_id:id,attack:25,crit:0,skill_id:skill.id,rarity:'common',skill_version:SKILL_VERSION,source:'initial'};
 });
}
export function starterSave(save,grants,additions){
 const next=mergeGrantedSave(save,grants);
 for(const grant of additions){
  if(!next.owned.includes(grant.card_id))next.owned.push(grant.card_id);
  next.attacks[grant.card_id]=25;next.crits[grant.card_id]=0;
  next.skills[grant.card_id]={id:grant.skill_id,rarity:'common',v:SKILL_VERSION};
 }
 return next;
}
export async function ensureStarterCards(env,uid,row,grants){
 const original=JSON.parse(row.save_json),additions=starterAdditions(original,grants);
 if(!additions.length)return {row,grants};
 const next=starterSave(original,grants,additions),now=Date.now();
 const statements=[env.DB.prepare('UPDATE demo_saves SET save_json=?,revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=? AND revision=?')
  .bind(JSON.stringify(next),uid,row.revision),
  ...additions.map(g=>env.DB.prepare(`INSERT INTO skill_grants(uid,card_id,attack,crit,skill_id,rarity,skill_version,source,roll_id,updated_at)
    SELECT ?,?,?,?,?,?,?,?,NULL,? WHERE EXISTS(SELECT 1 FROM demo_saves s,json_each(s.save_json,'$.owned') c
    WHERE s.uid=? AND s.revision=? AND c.value=?) ON CONFLICT(uid,card_id) DO NOTHING`)
   .bind(uid,g.card_id,25,0,g.skill_id,'common',SKILL_VERSION,'initial',now,uid,row.revision+1,g.card_id))];
 const [write]=await env.DB.batch(statements);
 if(write.meta?.changes!==1){
  const latest=await env.DB.prepare('SELECT save_json,revision,updated_at FROM demo_saves WHERE uid=?').bind(uid).first();
  return {row:latest,grants:await grantsFor(env,uid)};
 }
 return {row:{...row,save_json:JSON.stringify(next),revision:row.revision+1},grants:[...grants,...additions]};
}
export function fillDeck(ids,save,grants){
 const verified=new Set(grants.map(g=>g.card_id));
 const kept=[...new Set((Array.isArray(ids)?ids:[]).filter(id=>save.owned?.includes(id)&&verified.has(id)))];
 for(const id of [...STARTER_IDS,...save.owned]){if(kept.length===9)break;if(verified.has(id)&&!kept.includes(id))kept.push(id)}
 return kept;
}

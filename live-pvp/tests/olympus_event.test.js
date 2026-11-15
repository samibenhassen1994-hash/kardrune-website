import test from 'node:test';
import assert from 'node:assert/strict';
import {SKILL_BY_ID,OLYMPUS_HEROES,OLYMPUS_IDS,fixedOlympusSkill,validSkillForCard,OLYMPUS_COST,OLYMPUS_RATE_PER_1000} from '../../shared/skill_catalog.js';
import {resolveDuelFromStarter} from '../src/rules.js';
import {rollCard,mergeGrantedSave} from '../../functions/api/_lib/skill_store.js';
import {forgeAttempt} from '../../functions/api/_lib/forge.js';
const card=(hero,skillId,attack=100)=>({id:`${hero}:3`,hero,stage:3,attack,crit:0,skillId});
test('server event draws use exact 20% boundary, fixed gods and boosted normal stages',()=>{
 let divine=0;
 for(let n=0;n<1000;n++){
  const values=[n,0,0,0,0,0,0,0];
  const result=rollCard(false,true,()=>values.shift()??0);
  if(result.skill.id.startsWith('D'))divine++;
 }
 assert.equal(divine,200);
 for(let i=0;i<6;i++){
  const values=[99,i];const c=rollCard(false,true,()=>values.shift()??0);
  assert.equal(c.id,`${OLYMPUS_IDS[i]}:3`);assert.equal(c.attack,60);assert.equal(c.crit,8);
  assert.equal(c.skill.id,OLYMPUS_HEROES[OLYMPUS_IDS[i]].skillId);
 }
 for(const [ticket,stage] of [[0,1],[549,1],[550,2],[849,2],[850,3],[999,3]]){
  const values=[200,ticket,34];const c=rollCard(false,true,()=>values.shift()??0);
  assert.equal(c.id,`dren:${stage}`);assert.ok(!c.skill.id.startsWith('D'));
 }
});
test('divine grants survive cloud merge and cannot enter Forge',async()=>{
 const grants=OLYMPUS_IDS.map(hero=>({card_id:`${hero}:3`,attack:100,crit:25,
  skill_id:OLYMPUS_HEROES[hero].skillId,skill_version:1}));
 const save=mergeGrantedSave({owned:['sam:1'],attacks:{'sam:1':49},crits:{'sam:1':7}},grants);
 assert.equal(save.owned.length,7);assert.equal(save.attacks['sam:1'],49);
 for(const g of grants){assert.equal(save.skills[g.card_id].id,g.skill_id);
  await assert.rejects(forgeAttempt({},'u',{requestId:'a'.repeat(32),cardId:g.card_id,color:'red',stat:'SKILL',revision:1}),/FORGE_INVALID/);}
});
test('all six Olympus heroes are immutable Ultra cards at cap and have unique fixed skills',()=>{
 assert.equal(OLYMPUS_IDS.length,6);
 assert.equal(OLYMPUS_COST,1200);
 assert.equal(OLYMPUS_RATE_PER_1000,200);
 for(const id of OLYMPUS_IDS){
  const skillId=OLYMPUS_HEROES[id].skillId;
  assert.equal(SKILL_BY_ID[skillId].rarity,'ultra');
  assert.equal(fixedOlympusSkill(`${id}:3`),skillId);
  assert.equal(validSkillForCard(`${id}:3`,skillId,3),true);
  assert.equal(validSkillForCard(`${id}:2`,skillId,2),false);
  assert.equal(validSkillForCard('sam:3',skillId,3),false);
 }
});
test('Zeus is strongest on the first normal attack',()=>{
 const r=resolveDuelFromStarter(card('zeus','D1'),card('sam','C3'),0,()=>.99);
 assert.equal(r.log.find(e=>e.kind==='hit'&&e.actor===0).damage,140);
});
test('Athena blocks only 25% of her first hit',()=>{
 const r=resolveDuelFromStarter(card('athena','D4'),card('sam',null),1,()=>.99);
 assert.equal(r.log.find(e=>e.kind==='hit'&&e.target===0).damage,75);
});
test('Apollo heals 45 HP only after surviving the first direct hit',()=>{
 const r=resolveDuelFromStarter(card('apollo','D6'),card('sam',null),1,()=>.99);
 const heals=r.log.filter(e=>e.kind==='heal'&&e.source===0);
 assert.equal(heals.length,1);
 assert.equal(heals[0].heal,45);
});
test('next card receives once-only CRIT buff, hit protection, healing or ATK buff',()=>{
 const a=card('sam',null,60),b=card('lira',null,60);
 for(const blessing of Object.values(OLYMPUS_HEROES).map(g=>({skillId:g.skillId,...g.blessing}))){
  const r=resolveDuelFromStarter(a,b,0,()=>.99,[blessing,null]);
  assert.equal(r.log.filter(e=>e.kind==='skill'&&e.detail==='next_card_blessing').length,0);
  assert.ok(r.log.some(e=>e.kind==='skill'&&e.status==='next_card_blessing'));
 }
 const r=resolveDuelFromStarter(a,b,0,()=>.99,[{skillId:'D1',type:'attack_pct',value:15},null]);
 assert.equal(r.log.find(e=>e.kind==='hit'&&e.actor===0).damage,69);
});

test('all six divine effects and inherited bonuses have exact server values',()=>{
 const enemy=card('sam',null,100);
 const duel=(hero,blessing=null,crit=0,rng=()=>.99)=>resolveDuelFromStarter({...card(hero,OLYMPUS_HEROES[hero]?.skillId??null),crit},enemy,1,rng,[blessing,null]);
 const hits=(r,actor)=>r.log.filter(e=>e.kind==='hit'&&e.actor===actor);
 assert.equal(hits(duel('poseidon'),0)[0].damage,116);
 assert.deepEqual(hits(duel('poseidon'),1).slice(0,2).map(e=>e.damage),[70,100]);
 assert.equal(duel('hades').log.find(e=>e.kind==='heal'&&e.source===0).heal,12);
 assert.equal(hits(duel('ares'),0)[0].damage,127);
 assert.deepEqual(hits(duel('athena'),1).slice(0,2).map(e=>e.damage),[75,100]);
 for(const hero of OLYMPUS_IDS){
  const blessing={skillId:OLYMPUS_HEROES[hero].skillId,...OLYMPUS_HEROES[hero].blessing};
  const r=duel('lira',blessing);
  assert.equal(r.log.filter(e=>e.status==='next_card_blessing').length,1);
  if(hero==='zeus')assert.equal(hits(r,0)[0].damage,115);
  if(hero==='ares')assert.equal(hits(r,0)[0].damage,110);
  if(hero==='poseidon')assert.deepEqual(hits(r,1).slice(0,2).map(e=>e.damage),[80,100]);
  if(hero==='hades')assert.equal(r.log.find(e=>e.kind==='heal'&&e.source===0).heal,8);
  if(hero==='apollo'){const heals=r.log.filter(e=>e.kind==='heal'&&e.source===0);assert.equal(heals.length,1);assert.equal(heals[0].heal,60);}
  if(hero==='athena'){
   assert.equal(hits(duel('lira',blessing,0,()=>.02),0)[0].critical,true);
   assert.equal(hits(duel('lira',null,0,()=>.02),0)[0].critical,false);
   assert.equal(hits(duel('lira',blessing,25,()=>.26),0)[0].critical,false);
  }
 }
});

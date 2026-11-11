import test from 'node:test';
import assert from 'node:assert/strict';
import {SKILL_BY_ID,OLYMPUS_HEROES,OLYMPUS_IDS,fixedOlympusSkill,validSkillForCard,OLYMPUS_COST,OLYMPUS_RATE_PER_1000} from '../../shared/skill_catalog.js';
import {resolveDuelFromStarter} from '../src/rules.js';
const card=(hero,skillId,attack=100)=>({id:`${hero}:3`,hero,stage:3,attack,crit:0,skillId});
test('all six Olympus heroes are immutable Ultra cards at cap and have unique fixed skills',()=>{
 assert.equal(OLYMPUS_IDS.length,6);
 assert.equal(OLYMPUS_COST,1200);
 assert.equal(OLYMPUS_RATE_PER_1000,100);
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

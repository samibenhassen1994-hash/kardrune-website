import test from 'node:test';
import assert from 'node:assert/strict';
import {generateBotDeck,chooseBotCard,allocateBotName,botWaitMs,lossPenalty} from '../src/bot_policy.js';
import {validSkillForStage} from '../../shared/skill_catalog.js';
import {CARD_STAT_LIMITS} from '../../shared/card_stat_limits.js';
const seeded=()=>{let s=42;return()=>((s=Math.imul(s,1664525)+1013904223>>>0)/4294967296)};
test('legal decks and decisions across all leagues',()=>{
 const rng=seeded();
 const ranges=[[[8,9],[0,1],[0,0]],[[6,8],[1,3],[0,0]],[[2,4],[5,7],[0,0]],[[0,2],[4,6],[2,4]],[[0,0],[1,3],[6,8]],[[0,0],[0,1],[8,9]]];
 [0,100,250,500,900,1500].forEach((points,index)=>{
  for(let n=0;n<100;n++){
   const deck=generateBotDeck(points,rng);assert.equal(new Set(deck.map(c=>c.id)).size,9);
   for(let stage=1;stage<=3;stage++){
    const count=deck.filter(c=>c.stage===stage).length,[lo,hi]=ranges[index][stage-1];assert.ok(count>=lo&&count<=hi);
   }
   for(const c of deck){assert.ok(validSkillForStage(c.skillId,c.stage));for(const stat of ['attack','crit']){const [lo,hi]=CARD_STAT_LIMITS[c.stage][stat];assert.ok(c[stat]>=lo&&c[stat]<=hi)}}
   const hand=deck.slice(0,3),chosen=chooseBotCard({hand,remaining:deck,points},rng);assert.ok(hand.some(c=>c.id===chosen));
  }
 });
});
test('persistent name allocation survives new allocator calls',async()=>{
 const values=new Map(),tx={get:async k=>values.get(k),put:async(k,v)=>values.set(k,v)};
 const storage={transaction:async f=>f(tx)},names=new Set();
 for(let i=0;i<10000;i++)names.add(await allocateBotName(storage,'player'));
 assert.equal(names.size,10000);
 assert.equal(values.get('bot-name-sequence:player'),'10000');
});
test('waiting and league penalty boundaries',()=>{
 assert.equal(botWaitMs(()=>0),15000);assert.equal(botWaitMs(()=>.999999),25000);
 assert.equal(botWaitMs(()=>.5),20000);
 assert.equal(new Set([0,.25,.5,.75,.999999].map(v=>botWaitMs(()=>v))).size,5);
 assert.deepEqual([0,100,250,500,900,1500].map(lossPenalty),[0,5,10,15,20,20]);
});

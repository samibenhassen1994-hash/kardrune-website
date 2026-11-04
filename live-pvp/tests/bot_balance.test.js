import test from 'node:test';
import assert from 'node:assert/strict';
import {generateBotDeck,chooseBotCard} from '../src/bot_policy.js';
import {buildHand,rollInitiative,starterForRound,resolveDuelFromStarter,pickWinner} from '../src/rules.js';
import {CARD_STAT_LIMITS} from '../../shared/card_stat_limits.js';
test('reproducible full combat simulation across six leagues and representative decks',t=>{
 const simulate=()=>{
 let seed=117;const rng=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/4294967296);
 return [0,100,250,500,900,1500].map(points=>{
  const results={points,wins:0,losses:0,draws:0};
  for(let n=0;n<200;n++){
   const decks=[generateBotDeck(points,rng),generateBotDeck(points,rng)];
   // Reference human decks: low/mid/high legal stats, original skill rolls.
   for(const c of decks[0])for(const stat of ['attack','crit']){const [lo,hi]=CARD_STAT_LIMITS[c.stage][stat];c[stat]=Math.round(lo+(hi-lo)*(n%3)/2);}
   const used=[[],[]],scores=[0,0],initiative=rollInitiative(rng);
   for(let round=1;round<=3&&!scores.includes(2);round++){
    const hands=decks.map((d,i)=>buildHand(d,used[i]));
    const choice=chooseBotCard({hand:hands[1],remaining:decks[1].filter(c=>!used[1].includes(c.id)),points,score:[scores[1],scores[0]],style:['aggressive','defensive','strategic'][n%3]},rng);
    const cards=[hands[0][Math.floor(rng()*hands[0].length)],hands[1].find(c=>c.id===choice)];
    cards.forEach((c,i)=>used[i].push(c.id));
    const result=resolveDuelFromStarter(...cards,starterForRound(initiative.starter,round),rng);
    assert.ok(result.log.length>0);assert.ok(result.hp.every(Number.isFinite));
    if(result.winner!=='draw')scores[result.winner]++;
   }
   const winner=pickWinner(scores);results[winner==='draw'?'draws':winner===1?'wins':'losses']++;
  }
  assert.equal(results.wins+results.losses+results.draws,200);return results;
 });};
 const first=simulate();assert.deepEqual(simulate(),first);t.diagnostic(JSON.stringify(first));
});

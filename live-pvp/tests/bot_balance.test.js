import test from 'node:test';
import assert from 'node:assert/strict';
import {generateBotDeck,chooseBotCard} from '../src/bot_policy.js';
import {SKILLS,SKILL_WEIGHTS,RARITIES,SKILL_VERSION} from '../../shared/skill_catalog.js';
import {buildHand,rollInitiative,starterForRound,resolveDuelFromStarter,pickWinner} from '../src/rules.js';
import {CARD_STAT_LIMITS} from '../../shared/card_stat_limits.js';
// Synthetic cohorts, not production telemetry; independent of bot generation.
const compositions=[[8,1,0],[7,2,0],[3,6,0],[1,5,3],[0,2,7],[0,0,9]];
const heroes=['sam','lira','rhea','dren','tor','aria','kael','neris','nyra'];
function playerDeck(league,cohort,rng){
 const cards=[];
 compositions[league].forEach((count,i)=>{
  const stage=i+1;
  for(let n=0;n<count;n++){
   const roll=([lo,hi])=>Math.round(lo+(hi-lo)*([.15,.4,.7][cohort]+rng()*.25));
   let ticket=Math.floor(rng()*1000),rarity=0;
   while(ticket>=SKILL_WEIGHTS[stage][rarity])ticket-=SKILL_WEIGHTS[stage][rarity++];
   const skills=SKILLS.filter(s=>s.rarity===RARITIES[rarity]),skill=skills[Math.floor(rng()*skills.length)];
   cards.push({id:`${heroes[n]}:${stage}`,hero:heroes[n],stage,attack:roll(CARD_STAT_LIMITS[stage].attack),crit:roll(CARD_STAT_LIMITS[stage].crit),skillId:skill.id,skillVersion:SKILL_VERSION});
  }
 });
 for(let i=cards.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[cards[i],cards[j]]=[cards[j],cards[i]];}return cards;
}
function playerChoice(hand,cohort,round,score,rng){
 if(rng()<[.15,.08,.03][cohort])return hand[Math.floor(rng()*hand.length)];
 const ranked=hand.map(card=>{
  const skill=SKILLS.find(s=>s.id===card.skillId),attack=card.attack*(1+card.crit/100),hp=[0,240,340,430][card.stage];
  const value=attack*(round%2?1.15:1)+hp*(round%2?.12:.2)+(RARITIES.indexOf(skill.rarity)+1)*3;
  return {card,value};
 }).sort((a,b)=>b.value-a.value);
 return ranked[round===1&&score[1]===0&&ranked[1].value>ranked[0].value*.93&&rng()<.25?1:0].card;
}
test('independent player cohorts with realistic choices and reproducible seeds',t=>{
 const simulate=seedValue=>{
 let seed=seedValue;const rng=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/4294967296);
 return [0,100,250,500,900,1500].map((points,league)=>{
  const results={points,wins:0,losses:0,draws:0,cohorts:[0,0,0]};
  for(let n=0;n<3000;n++){
   const cohort=n%10<2?0:n%10<8?1:2;
   const decks=[playerDeck(league,cohort,rng),generateBotDeck(points,rng)];
   const used=[[],[]],scores=[0,0],initiative=rollInitiative(rng);
   for(let round=1;round<=3&&!scores.includes(2);round++){
    const hands=decks.map((d,i)=>buildHand(d,used[i]));
    const choice=chooseBotCard({hand:hands[1],remaining:decks[1].filter(c=>!used[1].includes(c.id)),points,score:[scores[1],scores[0]],style:['aggressive','defensive','strategic'][n%3]},rng);
    const cards=[playerChoice(hands[0],cohort,round,scores,rng),hands[1].find(c=>c.id===choice)];
    cards.forEach((c,i)=>used[i].push(c.id));
    const result=resolveDuelFromStarter(...cards,starterForRound(initiative.starter,round),rng);
    assert.ok(result.log.length>0);assert.ok(result.hp.every(Number.isFinite));
    if(result.winner!=='draw')scores[result.winner]++;
   }
   const winner=pickWinner(scores);results[winner==='draw'?'draws':winner===0?'wins':'losses']++;
   if(winner===0)results.cohorts[cohort]++;
  }
  assert.equal(results.wins+results.losses+results.draws,3000);return results;
 });};
 const calibration=simulate(117),validation=simulate(97139);assert.deepEqual(simulate(97139),validation);
 const holdout=simulate(412831);
 t.diagnostic(JSON.stringify({calibration,validation,holdout}));
 const targets=[[70,80],[65,75],[60,70],[55,65],[50,60],[45,55]];
 for(const rows of [calibration,validation,holdout])rows.forEach((row,i)=>{
  const rate=row.wins/30;assert.ok(rate>=targets[i][0]&&rate<=targets[i][1],`league ${i}: ${rate.toFixed(2)}% outside target`);
 });
});

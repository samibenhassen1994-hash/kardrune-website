import {CARD_STAT_LIMITS,effectiveCardStats} from '../../shared/card_stat_limits.js';
import {SKILLS,SKILL_WEIGHTS,RARITIES,SKILL_VERSION} from '../../shared/skill_catalog.js';
import {leagueFor} from '../../functions/api/_lib/ranked_leagues.js';

const heroes=['sam','lira','rhea','dren','tor','aria','kael','neris','nyra'];
const ranges=[[[8,9],[0,1],[0,0]],[[6,8],[1,3],[0,0]],[[2,4],[5,7],[0,0]],[[0,2],[4,6],[2,4]],[[0,0],[1,3],[6,8]],[[0,0],[0,1],[8,9]]];
const leagues=['Bronze','Silver','Gold','Platinum','Diamond','Legend'];
// Pregame stat quantiles only: preserve legal bounds, skill odds and combat RNG.
// Keep weak/balanced/strong variety while making entry leagues more forgiving.
const statQuantileScale=[.82,1.08,.93,1.03,1,1.05];
const randomChoiceChance=[.9,.7,.45,.3,.15,.08];
const syllables=['vael','mor','zyr','eld','thal','kael','drav','nyr','ael','vor','ryn','sha','tor','vel','lys','nar'];
const pick=(items,rng)=>items[Math.floor(rng()*items.length)];

// Bijective base-16: an allocated positive persistent sequence never repeats.
export function botName(sequence){
 let n=BigInt(sequence);if(n<1n)throw new RangeError('Positive sequence required');
 let name='';while(n>0n){n--;name=syllables[Number(n%16n)]+name;n/=16n;}
 return name[0].toUpperCase()+name.slice(1);
}
export const botWaitMs=rng=>15000+Math.floor(Math.max(0,Math.min(.999999999,rng()))*5001);
export const lossPenalty=points=>[0,5,10,15,20,20][leagues.indexOf(leagueFor(points).name)];

export function cardPower(card,style='strategic'){
 const stats=effectiveCardStats(card.stage,card.attack,card.crit);
 const hp=[0,240,340,430][card.stage];
 const skill=SKILLS.find(s=>s.id===card.skillId);
 const defensive=['shield','heal','dodge'].includes(skill?.vfx);
 const utility=1+Math.max(0,RARITIES.indexOf(skill?.rarity))*.06;
 return (stats.attack*(1+stats.crit/100)*(style==='aggressive'?1.2:1)
  +hp*(style==='defensive'?.22:.15))*utility*(defensive&&style==='defensive'?1.12:1);
}

// Input deliberately excludes the opponent's hidden selection and combat RNG.
export function chooseBotCard({hand,remaining=[],points=0,style='strategic',score=[0,0]},rng){
 if(!hand.length)throw new RangeError('Empty bot hand');
 const level=leagues.indexOf(leagueFor(points).name);
 if(rng()<randomChoiceChance[level])return pick(hand,rng).id;
 const behind=score[0]<score[1],urgent=score[1]===1;
 const remainingPower=remaining.length?remaining.reduce((n,c)=>n+cardPower(c,style),0)/remaining.length:0;
 const ranked=hand.map(card=>{
  let value=cardPower(card,style);
  if(level>=3&&style==='strategic'&&!behind&&!urgent&&remaining.length>3)
   value-=Math.max(0,value-remainingPower)*.6;
  return {id:card.id,value:value*(.85+rng()*.3)};
 });
 return ranked.sort((a,b)=>b.value-a.value)[0].id;
}

// Durable Object transactions serialize allocation across sessions/restarts.
export async function allocateBotName(storage,uid){
 return storage.transaction(async tx=>{
  const key=`bot-name-sequence:${uid}`;
  const sequence=BigInt(await tx.get(key)??'0')+1n;
  await tx.put(key,sequence.toString());
  return botName(sequence);
 });
}

export function generateBotDeck(points,rng){
 const index=leagues.indexOf(leagueFor(points).name),range=ranges[index],valid=[];
 for(let a=range[0][0];a<=range[0][1];a++)for(let b=range[1][0];b<=range[1][1];b++){
  const c=9-a-b;if(c>=range[2][0]&&c<=range[2][1])valid.push([a,b,c]);
 }
 const counts=pick(valid,rng),tier=rng(),band=tier<.25?[0,.4]:tier<.8?[.25,.8]:[.6,1];
 const deck=[];
 for(let stage=1;stage<=3;stage++){
  const pool=[...heroes];
  for(let i=0;i<counts[stage-1];i++){
   const hero=pool.splice(Math.floor(rng()*pool.length),1)[0];
   const roll=([lo,hi])=>Math.min(hi,lo+Math.floor((band[0]+rng()*(band[1]-band[0]))*statQuantileScale[index]*(hi-lo+1)));
   let ticket=Math.floor(rng()*1000),rarity=0;
   while(rarity<5&&ticket>=SKILL_WEIGHTS[stage][rarity])ticket-=SKILL_WEIGHTS[stage][rarity++];
   const skill=pick(SKILLS.filter(s=>s.rarity===RARITIES[rarity]&&!s.id.startsWith('D')),rng);
   deck.push({id:`${hero}:${stage}`,hero,stage,...effectiveCardStats(stage,roll(CARD_STAT_LIMITS[stage].attack),roll(CARD_STAT_LIMITS[stage].crit)),skillId:skill.id,skillRarity:skill.rarity,skillVersion:SKILL_VERSION});
  }
 }
 for(let i=deck.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[deck[i],deck[j]]=[deck[j],deck[i]];}
 return deck;
}

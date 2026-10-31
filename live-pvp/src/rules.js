// Pure rules shared by the live match coordinator.
import {resolveSkillDuel} from './skill_duel.js';
export const hpByStage=stage=>[0,240,340,430][stage]||240;
export function buildHand(deck,used,round){
 // Three options per round. Remaining cards are not repeated within a match.
 const remaining=deck.filter(card=>!used.includes(card.id));
 return remaining.slice(0,3);
}
export function resolveDuel(a,b,random=Math.random){
 return resolveSkillDuel([a,b],random);
}
export function rollInitiative(random=Math.random){
 const attempts=[];
 for(let count=0;count<100;count++){
  const rolls=[1+Math.floor(random()*20),1+Math.floor(random()*20)];
  attempts.push(rolls);
  if(rolls[0]!==rolls[1])return {rolls,attempts,starter:rolls[0]>rolls[1]?0:1};
 }
 return {rolls:[20,19],attempts,starter:0};
}
export function starterForRound(initialStarter,round){
 return (initialStarter+Math.max(0,round-1))%2;
}
export function resolveDuelFromStarter(a,b,starter,random=Math.random){
 return resolveSkillDuel([a,b],random,starter);
}
export function matchComplete(scores, roundsPlayed){return scores.some(score=>score>=2)||roundsPlayed>=3}
export function pickWinner(scores){return scores[0]===scores[1]?'draw':scores[0]>scores[1]?0:1}

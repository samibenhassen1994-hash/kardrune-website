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
export function matchComplete(scores, roundsPlayed){return scores.some(score=>score>=2)||roundsPlayed>=3}
export function pickWinner(scores){return scores[0]===scores[1]?'draw':scores[0]>scores[1]?0:1}

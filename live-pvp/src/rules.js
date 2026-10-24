// Pure rules shared by the live match coordinator.
export const hpByStage=stage=>[0,240,340,430][stage]||240;
export function buildHand(deck,used,round){
 // Three options per round. Remaining cards are not repeated within a match.
 const remaining=deck.filter(card=>!used.includes(card.id));
 return remaining.slice(0,3);
}
export function resolveDuel(a,b,random=Math.random){
 const hp=[hpByStage(a.stage),hpByStage(b.stage)],log=[];
 let turn=random()<.5?0:1;
 for(let i=0;i<100&&hp[0]>0&&hp[1]>0;i++){
  const card=turn===0?a:b,critical=random()<card.crit/100;
  const amount=card.attack*(critical?2:1),enemy=1-turn;
  hp[enemy]=Math.max(0,hp[enemy]-amount);
  log.push({actor:turn,damage:amount,critical,hp:hp[enemy]});
  turn=enemy;
 }
 return {winner:hp[0]===hp[1]?'draw':hp[0]>0?0:1,log,hp};
}
export function pickWinner(scores){return scores[0]===scores[1]?'draw':scores[0]>scores[1]?0:1}

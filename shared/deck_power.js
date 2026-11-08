import {effectiveCardStats} from './card_stat_limits.js';
import {rarityIndex} from './skill_catalog.js';
// Display-only: must match Flutter DeckPower. Never used for combat/rewards.
export function deckPower(deck,save){
 if(!Array.isArray(deck)||!Array.isArray(save?.owned))return 0;
 let total=0;
 for(const id of [...new Set(deck)].filter(id=>save.owned.includes(id)).slice(0,9)){
  if(typeof id!=='string'||!/^(sam|lira|rhea|dren|tor|aria|kael|neris|nyra):[123]$/.test(id))continue;
  const stage=Number(id.split(':')[1]),stats=effectiveCardStats(stage,save.attacks?.[id],save.crits?.[id]),rank=rarityIndex(save.skills?.[id]);
  total+=stage*100+Math.floor((stats.attack*(100+stats.crit)+50)/100)+(rank>=stage-1?[10,20,35,50,75,100][rank]:0);
 }
 return total;
}

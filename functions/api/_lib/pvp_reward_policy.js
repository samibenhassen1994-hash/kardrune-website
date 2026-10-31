export function rewardForHistory(history,uid){
 if(!history||!['completed','opponent_disconnected','replay_timeout'].includes(history.reason))return 0;
 if(![history.player_a,history.player_b].includes(uid))return 0;
 return history.winner_uid===uid?100:0;
}

export const PVP_REWARD_LIMITS=Object.freeze({daily:10,perOpponent:3});

export function rewardAccess(history,uid,claims={total:0,againstOpponent:0}){
 if(rewardForHistory(history,uid)!==100)return {allowed:false,reason:'ineligible'};
 if(Number(claims.total)>=PVP_REWARD_LIMITS.daily)
  return {allowed:false,reason:'daily_limit'};
 if(Number(claims.againstOpponent)>=PVP_REWARD_LIMITS.perOpponent)
  return {allowed:false,reason:'opponent_limit'};
 return {allowed:true,opponent:history.player_a===uid?history.player_b:history.player_a};
}

export function pendingRewardMatchIds(rows){
 return [...new Set((rows||[]).map(row=>row?.id).filter(id=>typeof id==='string'&&id.length>0))];
}

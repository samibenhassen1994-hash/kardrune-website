export function rewardForHistory(history,uid){
 if(!history||history.reason!=='completed')return 0;
 if(![history.player_a,history.player_b].includes(uid))return 0;
 return history.winner_uid===uid?100:0;
}

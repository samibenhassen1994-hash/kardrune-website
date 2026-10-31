const count=value=>Number.isSafeInteger(value)&&value>=0?value:0;

// Only display preferences cross the client/server trust boundary. Cards,
// currency and competitive counters are rebuilt from D1-owned state.
export function isolateCompetitiveSave(input,previous=null){
 const trusted=previous&&typeof previous==='object'?previous:{};
 return {
  ...input,
  owned:[],attacks:{},crits:{},skills:{},
  shards:count(trusted.shards),
  duels:count(trusted.duels),
  wins:count(trusted.wins),
  pulls:count(trusted.pulls),
  practiceDaily:trusted.practiceDaily&&typeof trusted.practiceDaily==='object'
   ?trusted.practiceDaily:{day:'',count:0},
  pendingDuplicate:trusted.pendingDuplicate??null,
 };
}

export function selectVerifiedActive(requested,previous,owned){
 if(owned.includes(requested))return requested;
 if(owned.includes(previous))return previous;
 return owned[0]??null;
}

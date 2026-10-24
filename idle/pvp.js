/* Friendly asynchronous PvP UI; requires Firebase sign-in and D1 migration 0002. */
(function(root){
'use strict';
const $=id=>document.getElementById(id);
let cloudRequest=null,me=null,poll=null,busy=false;
function state(text){$('pvp-online-status').textContent=text}
function show(data){
 $('pvp-queue-button').hidden=data.state!=='idle';
 $('pvp-leave-button').hidden=data.state==='idle';
 $('pvp-online-result').hidden=data.state!=='matched';
 if(data.state==='idle')state('Ready to find an online opponent.');
 if(data.state==='waiting')state('Searching for another signed-in player…');
 if(data.state==='matched'){
  state('Friendly duel complete · '+(data.won?'VICTORY':'DEFEAT'));
  $('pvp-match-rival').textContent=data.opponent.name;
  $('pvp-match-stats').textContent='Your card: '+data.you.card.id+' · ATK '+data.you.card.attack+' · CRIT '+data.you.card.crit+'% · HP '+data.you.card.maxHp+
   ' | Opponent: '+data.opponent.card.id+' · ATK '+data.opponent.card.attack+' · CRIT '+data.opponent.card.crit+'% · HP '+data.opponent.card.maxHp;
  $('pvp-match-log').textContent=data.replay.map((hit,i)=>(i+1)+'. '+(hit.actor==='you'?'You':'Opponent')+' dealt '+hit.damage+(hit.crit?' (CRIT)':'')+' · '+hit.remainingHp+' HP left').join('\n');
 }
}
async function fetchStatus(){
 if(!cloudRequest||!me)return;
 const result=await cloudRequest('pvp/status');
 if(!me)return;
 show(result);
 if(result.state==='matched')stopPoll();
}
function stopPoll(){if(poll!==null){clearInterval(poll);poll=null}}
function setSession(user,request){
 stopPoll();me=user;cloudRequest=request;
 $('pvp-online-controls').hidden=!user;
 $('pvp-sign-in-hint').hidden=Boolean(user);
 $('pvp-online-result').hidden=true;
 if(!user)return;
 fetchStatus().catch(e=>state('PvP setup needed: '+e.message));
 poll=setInterval(()=>fetchStatus().catch(e=>state('Connection problem: '+e.message)),10000);
}
function setup(){
 $('pvp-queue-button').addEventListener('click',async()=>{
  if(!me||!cloudRequest||busy)return;
  busy=true;try{state('Joining queue…');const data=await cloudRequest('pvp/join','POST');show(data);await fetchStatus()}catch(e){state(e.message)}finally{busy=false}
 });
 $('pvp-leave-button').addEventListener('click',async()=>{
  if(!me||!cloudRequest||busy)return;
  busy=true;try{await cloudRequest('pvp/leave','POST');show({state:'idle'});if(poll===null)poll=setInterval(()=>fetchStatus().catch(()=>{}),10000)}catch(e){state(e.message)}finally{busy=false}
 });
}
root.IDLE_PVP={setup,setSession};
})(window);

/* Realtime card-duel client. Existing friendly PvP remains intact. */
(function(root){
'use strict';
const $=id=>document.getElementById(id);
let api=null,uid=null,socket=null,deck=[],hand=[],animating=false,roundActive=false;
const heroes=()=>root.IDLE_HERO_CATALOG||[];
const cardImage=id=>{const [h,stage]=id.split(':'),hero=heroes().find(x=>x.id===h);return hero?'./media/cards/'+hero.stages[Number(stage)-1]:null};
function status(s){$('live-pvp-state').textContent=s}
function drawCards(container,cards,interactive=false){
 container.replaceChildren();
 for(const c of cards){
  const item=document.createElement(interactive?'button':'div');
  item.className='live-pvp-card';item.type='button';
  const image=document.createElement('img');image.src=cardImage(c.id);image.alt=c.id;
  const text=document.createElement('span');text.textContent=c.id+' · ATK '+c.attack+' · CRIT '+c.crit+'% · HP '+([0,240,340,430][c.stage]);
  item.append(image,text);
  if(interactive)item.addEventListener('click',()=>play(c.id));
  container.append(item);
 }
}
function showDeckEditor(save){
 const area=$('live-deck-editor');area.replaceChildren();
 const owned=Array.isArray(save?.owned)?save.owned:[];
 for(const id of owned){
  const label=document.createElement('label');label.className='live-deck-choice';
  const check=document.createElement('input');check.type='checkbox';check.checked=deck.includes(id);
  check.addEventListener('change',()=>{if(check.checked){if(deck.length>=9){check.checked=false;status('Maximum nine cards in your deck');return}deck.push(id)}else deck=deck.filter(x=>x!==id);$('live-deck-count').textContent=deck.length+' / 9';});
  const image=document.createElement('img');image.src=cardImage(id);image.alt=id;
  const stat=document.createElement('span');stat.textContent=id+' · '+(save.attacks?.[id]||'?')+' ATK · '+(save.crits?.[id]||0)+'% CRIT';
  label.append(check,image,stat);area.append(label);
 }
 $('live-deck-count').textContent=deck.length+' / 9';
}
async function begin(){if(!api)return;
 try{
  const details=await api('pvp/live-ticket','POST');
  const dest=new URL(details.url);
  if(!['wss:','ws:'].includes(dest.protocol))throw Error('Invalid PvP endpoint');
  dest.pathname='/connect';dest.searchParams.set('ticket',details.ticket);
  socket=new WebSocket(dest.href);
  $('live-pvp-connect').disabled=true;
  socket.onopen=()=>status('Connected. Finding another live player…');
  socket.onclose=()=>{$('live-pvp-connect').disabled=false;roundActive=false;status('Connection closed. Reconnect to try again.')};
  socket.onerror=()=>status('Connection error. Please reconnect.');
  socket.onmessage=event=>{let msg;try{msg=JSON.parse(event.data)}catch{return}handle(msg)};
 }catch(e){status(e.message);$('live-pvp-connect').disabled=false}
}
function play(id){
 if(!roundActive||!socket||socket.readyState!==1)return;
 socket.send(JSON.stringify({type:'play',id}));roundActive=false;
 document.querySelectorAll('#live-hand button').forEach(x=>x.disabled=true);
 status('Card locked. Waiting for the other player…');
}
async function animate(msg){
 animating=true;
 const display=$('live-battle-replay');display.replaceChildren();
 const headline=document.createElement('div');
 headline.className='live-round-heading';headline.textContent='ROUND '+msg.round+' · '+msg.cards[0].id+' VS '+msg.cards[1].id;display.append(headline);
 drawCards($('live-round-cards'),msg.cards);
 for(const hit of msg.log){
  const line=document.createElement('div');line.className='live-hit';
  line.textContent=(hit.actor===0?'YOUR CARD':'RIVAL')+'  '+(hit.critical?'CRIT ×2 · ':'')+hit.damage+' DMG  ·  '+hit.hp+' HP';
  display.append(line);
  await new Promise(resolve=>setTimeout(resolve,450));
 }
 const end=document.createElement('strong');
 end.textContent=msg.winner==='draw'?'DRAW':msg.winner===0?'ROUND WON':'ROUND LOST';display.append(end);
 $('live-score').textContent=msg.score.join(' - ');
 animating=false;
 if(socket?.readyState===1)socket.send(JSON.stringify({type:'ready'}));
}
function handle(msg){
 if(msg.type==='waiting')status('In matchmaking queue…');
 if(msg.type==='error')status(msg.message);
 if(msg.type==='opponent_left')status('Opponent disconnected. Waiting for another player…');
 if(msg.type==='locked')status('Card selected. Waiting for rival…');
 if(msg.type==='hand'){
  hand=msg.hand;roundActive=true;
  status('ROUND '+msg.round+' · Pick one of your three cards against '+msg.opponent);
  $('live-hand-title').textContent='YOUR HAND · ROUND '+msg.round;
  drawCards($('live-hand'),hand,true);
 }
 if(msg.type==='round_result'){roundActive=false;animate(msg)}
 if(msg.type==='finished'){
  roundActive=false;status('MATCH FINISHED · '+(msg.winner==='you'?'VICTORY':msg.winner==='draw'?'DRAW':'DEFEAT'));
  $('live-hand').replaceChildren();
  $('live-pvp-connect').disabled=false;
 }
}
async function setSession(user,request){
 uid=user?.uid||null;api=request||null;
 if(socket){socket.close();socket=null}
 $('live-pvp-auth-hint').hidden=Boolean(uid);
 $('live-pvp-content').hidden=!uid;
 if(!uid)return;
 try{
  const result=await api('pvp/deck');deck=result.cards;
  showDeckEditor(root.IDLE_CLOUD?.getSave?.());
  status('Build your deck, then connect to a live match.');
 }catch(e){status('Deck database not ready: '+e.message)}
}
function setup(){
 $('live-deck-save').addEventListener('click',async()=>{
  if(!api)return;
  try{const result=await api('pvp/deck','PUT',{cards:deck});
   deck=result.cards;status('Deck saved · '+deck.length+' cards');
  }catch(e){status(e.message)}
 });
 $('live-pvp-connect').addEventListener('click',begin);
 $('live-pvp-disconnect').addEventListener('click',()=>{if(socket)socket.close();socket=null;$('live-pvp-connect').disabled=false;status('Disconnected')});
}
root.IDLE_LIVE_PVP={setup,setSession};
})(window);

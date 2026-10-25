(function(root){
'use strict';
const $=id=>document.getElementById(id),wait=ms=>new Promise(r=>setTimeout(r,ms));
const asset=id=>{const [name,stage]=id.split(':'),hero=(root.IDLE_HERO_CATALOG||[]).find(h=>h.id===name);return hero?'./media/cards/'+hero.stages[Number(stage)-1]:''};
let ws=null,roundToken=0,tick=null,toastTimer=null,hand=[],allowed=false,chosen=null,connected=false;
const view=()=>$('pvp-battle-view');
function text(id,value){$(id).textContent=value}
function popup(title,description='',crit=false){
 const el=$('pvp-round-popup');clearTimeout(toastTimer);
 text('pvp-popup-title',title);text('pvp-popup-description',description);
 el.classList.toggle('critical',crit);el.hidden=false;
 toastTimer=setTimeout(()=>el.hidden=true,2000);
}
function phase(str){text('pvp-phase',str)}
function open(name){view().hidden=false;document.body.classList.add('pvp-battle-open');text('pvp-rival-name',name||'Rival');phase('Entering the arena…');popup('OPPONENT FOUND','Prepare your hand');}
function close(){view().hidden=true;document.body.classList.remove('pvp-battle-open');clearInterval(tick);roundToken++}
function cardNode(card,css=''){
 const el=document.createElement('div');el.className='pvp-battle-card '+css;el.dataset.id=card.id;
 const img=document.createElement('img');img.src=asset(card.id);img.alt=card.id;img.draggable=false;
 const label=document.createElement('span');label.textContent=card.id.toUpperCase()+' · '+card.attack+' ATK';
 el.append(img,label);return el;
}
function stopTimer(){clearInterval(tick);text('pvp-timer','--');$('pvp-timer').classList.remove('urgent')}
function showHand(msg){
 const token=++roundToken;allowed=false;chosen=null;hand=msg.hand||[];stopTimer();
 if(view().hidden)open(msg.opponent);else text('pvp-rival-name',msg.opponent||'Rival');
 text('pvp-round-number','ROUND '+msg.round);text('pvp-score',msg.score.join(' : '));
 $('pvp-own-fighter').replaceChildren();$('pvp-rival-fighter').replaceChildren();
 const list=$('pvp-hand');list.replaceChildren();phase('Drawing your hand…');
 if(msg.round>1)popup('ROUND '+msg.round,'Three new cards · choose one');
 hand.forEach((c,i)=>{
  const item=cardNode(c,'pvp-hand-card');item.style.animationDelay=(i*190)+'ms';item.tabIndex=0;item.role='button';
  item.setAttribute('aria-label','Play '+c.id);
  // Tap fallback is handled by the capturing click listener below.
  item.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();play(c.id)}});
  let drag=null,ignoreClick=false;
  item.addEventListener('click',e=>{if(ignoreClick){e.preventDefault();e.stopImmediatePropagation();ignoreClick=false}else play(c.id)},true);
  item.addEventListener('pointerdown',e=>{
   if(!allowed||e.button!==0)return;
   e.preventDefault();item.setPointerCapture?.(e.pointerId);
   drag={pointerId:e.pointerId,x:e.clientX,y:e.clientY,ghost:null,moved:false};
  });
  item.addEventListener('pointermove',e=>{
   if(!drag||drag.pointerId!==e.pointerId||!allowed)return;
   if(!drag.moved&&Math.hypot(e.clientX-drag.x,e.clientY-drag.y)>5){
    drag.moved=true;drag.ghost=cardNode(c,'pvp-drag-ghost');document.body.append(drag.ghost);
   }
   if(drag.ghost){
    drag.ghost.style.left=e.clientX+'px';drag.ghost.style.top=e.clientY+'px';
    const bounds=$('pvp-arena-drop').getBoundingClientRect();
    drag.ghost.classList.toggle('over-arena',e.clientY>=bounds.top&&e.clientY<=bounds.bottom);
   }
  });
  item.addEventListener('pointerup',e=>{
   if(!drag||drag.pointerId!==e.pointerId)return;
   const wasDragging=drag.moved;
   drag.ghost?.remove();drag=null;
   if(wasDragging){ignoreClick=true;setTimeout(()=>ignoreClick=false,400)}
   if(!wasDragging)return;
   const bounds=$('pvp-arena-drop').getBoundingClientRect();
   if(e.clientX>=bounds.left&&e.clientX<=bounds.right&&e.clientY>=bounds.top&&e.clientY<=bounds.bottom)play(c.id);
  });
  item.addEventListener('pointercancel',()=>{drag?.ghost?.remove();drag=null});
  list.append(item);
 });
 setTimeout(()=>{
  if(token!==roundToken)return;allowed=true;phase('Choose a card · drag upward or tap');
  const deadline=Number(msg.deadline)||Date.now()+10000;
  const update=()=>{const remaining=Math.max(0,Math.ceil((deadline-Date.now())/1000));text('pvp-timer',String(remaining));$('pvp-timer').classList.toggle('urgent',remaining<=3);if(!remaining){clearInterval(tick);allowed=false;phase('Time expired · server choosing a random card')}};
  update();tick=setInterval(update,120);
 },750);
}
function play(id){
 if(!allowed||!hand.some(c=>c.id===id)||ws?.readyState!==WebSocket.OPEN)return;
 allowed=false;stopTimer();chosen=hand.find(c=>c.id===id);
 ws.send(JSON.stringify({type:'play',id}));
 $('pvp-hand').querySelectorAll('.pvp-hand-card').forEach(el=>el.classList.toggle('unselected',el.dataset.id!==id));
 $('pvp-own-fighter').replaceChildren(cardNode(chosen,'pvp-fighter'));
 phase('Card locked · waiting for opponent…');
}
async function replay(msg){
 const token=++roundToken;allowed=false;stopTimer();$('pvp-hand').replaceChildren();
 const own=cardNode(msg.cards[0],'pvp-fighter'),rival=cardNode(msg.cards[1],'pvp-fighter rival');
 $('pvp-own-fighter').replaceChildren(own);$('pvp-rival-fighter').replaceChildren(rival);
 popup('CARDS REVEALED',msg.cards[0].id+' VS '+msg.cards[1].id);
 phase('Battle in progress');await wait(650);
 const hp=[ [0,240,340,430][msg.cards[0].stage], [0,240,340,430][msg.cards[1].stage] ];
 for(const hit of msg.log||[]){
  if(token!==roundToken)return;
  const attacker=hit.actor===0?own:rival,target=hit.actor===0?rival:own;
  attacker.classList.remove('strike');target.classList.remove('damaged','crit-damaged');void attacker.offsetWidth;
  attacker.classList.add('strike');target.classList.add(hit.critical?'crit-damaged':'damaged');
  const effect=document.createElement('div');effect.className='pvp-hit-effect'+(hit.critical?' crit':'');
  effect.textContent=(hit.actor===0?'YOU HIT RIVAL · ':'RIVAL HITS YOU · ')+(hit.critical?'CRITICAL!  ':'')+'−'+hit.damage;
  $('pvp-arena-effects').replaceChildren(effect);
  hp[1-hit.actor]=hit.hp;
  text('pvp-own-hp','HP '+hp[0]);text('pvp-rival-hp','HP '+hp[1]);
  await wait(hit.critical?800:480);
 }
 if(token!==roundToken)return;
 text('pvp-score',msg.score.join(' : '));
 const won=msg.winner===0,draw=msg.winner==='draw';
 popup(draw?'ROUND DRAW':won?'ROUND WON':'ROUND LOST',draw?'Both heroes fought to a draw':won?'Your card defeated the rival':'The rival card won the clash');
 phase('Round complete');await wait(2000);
 if(token===roundToken&&ws?.readyState===WebSocket.OPEN)ws.send(JSON.stringify({type:'ready'}));
}
function onMessage(msg){
 if(msg.type==='ping'){if(ws?.readyState===WebSocket.OPEN)ws.send(JSON.stringify({type:'pong'}));return}
 if(msg.type==='waiting')return;
 if(msg.type==='hand'){showHand(msg);return}
 if(msg.type==='opponent_locked'){phase(chosen?'Both cards selected · revealing…':'Opponent has chosen · your turn');return}
 if(msg.type==='locked'){
  if(msg.automatic){allowed=false;stopTimer();chosen=hand.find(c=>c.id===msg.card);if(chosen)$('pvp-own-fighter').replaceChildren(cardNode(chosen,'pvp-fighter'));popup('TIME EXPIRED','A random card was selected for you')}
  phase('Waiting for opponent…');return;
 }
 if(msg.type==='round_result'){replay(msg);return}
 if(msg.type==='finished'){
  roundToken++;stopTimer();allowed=false;
  const win=msg.winner==='you',tie=msg.winner==='draw';
  const title=tie?'MATCH DRAW':win?'VICTORY':'DEFEAT';
  popup(title,msg.reason==='opponent_disconnected'?(win?'Opponent disconnected · you win':'Connection lost · defeat'):'Final score '+msg.score.join(' : '));
  phase(title);text('pvp-final-result',title);$('pvp-finish').hidden=false;return;
 }
 if(msg.type==='error')popup('MATCH ERROR',msg.message);
}
function attach(socket){
 ws=socket;connected=true;$('pvp-finish').hidden=true;
 $('pvp-own-hp').textContent='HP —';$('pvp-rival-hp').textContent='HP —';
 socket.addEventListener('message',e=>{let msg;try{msg=JSON.parse(e.data)}catch{return}onMessage(msg)});
 socket.addEventListener('close',()=>{
  connected=false;stopTimer();allowed=false;
  if(!view().hidden&&$('pvp-finish').hidden){phase('Connection lost');text('pvp-final-result','DISCONNECTED');$('pvp-finish').hidden=false;popup('CONNECTION LOST','The match is forfeited')}
 });
}
function setup(){
 $('pvp-exit-battle').addEventListener('click',()=>{if(!confirm('Leaving a live match counts as defeat. Leave arena?'))return;ws?.close(4002,'Player left');close()});
 $('pvp-finish-back').addEventListener('click',()=>{ws?.close();close()});
 root.addEventListener('pagehide',()=>{if(connected)ws?.close(4002,'Page closed')});
}
root.IDLE_PVP_ARENA={setup,attach,open,close,onMessage,active:()=>!view().hidden};
})(window);

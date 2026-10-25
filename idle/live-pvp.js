/* Deck editor in Cards; live round combat UI remains in Tournament. */
(function(root){
'use strict';
const $=id=>document.getElementById(id);
const STORAGE='idle-pvp-deck-draft-v1';
let api=null,uid=null,socket=null,deck=[],saved=[],roundActive=false,loaded=false,dirty=false;
const heroes=()=>root.IDLE_HERO_CATALOG||[];
const save=()=>root.IDLE_CLOUD?.getSave?.()||{};
const cardImage=id=>{const [h,stage]=id.split(':'),hero=heroes().find(x=>x.id===h);return hero?'./media/cards/'+hero.stages[Number(stage)-1]:''};
function getDraft(){try{return JSON.parse(localStorage.getItem(STORAGE))}catch{return []}}
function setDraft(){try{localStorage.setItem(STORAGE,JSON.stringify(deck))}catch{}}
const layout=root.IDLE_DECK_LAYOUT;
const owned=()=>save().owned||[];
const validDeck=ids=>layout.normalize(ids,owned());
const selected=()=>layout.cards(deck);
function status(message){$('live-pvp-state').textContent=message}
function deckStatus(message){$('cards-deck-status').textContent=message}
function syncStatus(){if(!uid)deckStatus('Local draft · sign in to save your deck online.');else if(dirty)deckStatus('Unsaved changes · tap SAVE DECK.');else deckStatus('Deck saved to your account.')}
function updateDeck(ids){deck=validDeck(ids);dirty=JSON.stringify(selected())!==JSON.stringify(saved);setDraft();renderDeck()}
function insert(id,index){
 try{updateDeck(layout.put(deck,id,index,owned()))}
 catch(error){deckStatus(error.message)}
}
function remove(index){updateDeck(layout.remove(deck,index,owned()))}
function renderDeck(){
 const slots=$('cards-deck-slots');slots.replaceChildren();
 for(let i=0;i<9;i++){
  const id=deck[i],slot=document.createElement('button');slot.type='button';
  slot.className='deck-slot'+(id?' filled':'');slot.dataset.slot=i;
  slot.setAttribute('aria-label',id?'Remove '+id+' from deck slot '+(i+1):'Empty deck slot '+(i+1));
  const index=document.createElement('span');index.className='deck-slot-number';index.textContent=String(i+1).padStart(2,'0');
  slot.append(index);
  if(id){
   const img=document.createElement('img');img.src=cardImage(id);img.alt=id;img.draggable=false;slot.append(img);
   const name=document.createElement('span');name.className='deck-slot-name';name.textContent=id.replace(':',' · S');slot.append(name);
   const cross=document.createElement('span');cross.className='deck-slot-remove';cross.textContent='×';slot.append(cross);
   slot.addEventListener('click',()=>remove(i));
  }else{const add=document.createElement('span');add.className='deck-slot-plus';add.textContent='+';slot.append(add)}
  slot.addEventListener('dragover',e=>{e.preventDefault();slot.classList.add('drag-over')});
  slot.addEventListener('dragleave',()=>slot.classList.remove('drag-over'));
  slot.addEventListener('drop',e=>{e.preventDefault();slot.classList.remove('drag-over');const dragged=e.dataTransfer.getData('text/plain');if(dragged)insert(dragged,i)});
  slots.append(slot);
 }
 $('cards-deck-count').textContent=selected().length+' / 9';
 $('live-deck-count').textContent=selected().length+' / 9';
 syncStatus();refreshLabels();
}
function prepareCard(card,id){
 if(!owned().includes(id))return;
 const artwork=card.querySelector('.hero-image');
 card.draggable=false;
 card.querySelectorAll('img').forEach(img=>img.draggable=false);
 card.addEventListener('dragstart',e=>e.preventDefault());
 const button=document.createElement('button');button.type='button';button.className='deck-add-card';
 button.addEventListener('click',e=>{
  e.preventDefault();e.stopPropagation();
  if(deck.includes(id))remove(deck.indexOf(id));else insert(id);
 });
 card.append(button);
 root.IDLE_DECK_DRAG.attach(artwork,id,{
  image:cardImage(id),slots:$('cards-deck-slots'),
  onDrop:(dragged,index)=>insert(dragged,index)
 });
}
function refreshLabels(){
 document.querySelectorAll('#hero-grid .deck-add-card').forEach(button=>{
  const id=button.closest('[data-card-id]')?.dataset.cardId;
  if(!id)return;
  const inDeck=deck.includes(id);
  button.textContent=inDeck?'− REMOVE FROM DECK':'+ ADD TO DECK';
  button.classList.toggle('is-in-deck',inDeck);
  button.setAttribute('aria-label',(inDeck?'Remove ':'Add ')+id+(inDeck?' from':' to')+' PvP deck');
 });
}
function renderCardControls(){
 document.querySelectorAll('#hero-grid .hero-card[data-card-id]').forEach(card=>{
  if(!card.querySelector('.deck-add-card'))prepareCard(card,card.dataset.cardId);
 });
 refreshLabels();
}
function drawCards(container,cards,interactive=false){
 container.replaceChildren();
 for(const c of cards){
  const item=document.createElement(interactive?'button':'div');item.className='live-pvp-card';if(interactive)item.type='button';
  const image=document.createElement('img');image.src=cardImage(c.id);image.alt=c.id;
  const text=document.createElement('span');text.textContent=c.id+' · ATK '+c.attack+' · CRIT '+c.crit+'% · HP '+([0,240,340,430][c.stage]);
  item.append(image,text);if(interactive)item.addEventListener('click',()=>play(c.id));container.append(item);
 }
}
async function begin(){
 if(!api)return;
 if(dirty){status('Save your deck in Cards before matchmaking.');return}
 if(!saved.length){status('Build and save a deck in Cards first.');return}
 try{
  const details=await api('pvp/live-ticket','POST'),dest=new URL(details.url);
  if(!['wss:','ws:'].includes(dest.protocol))throw Error('Invalid PvP endpoint');
  dest.pathname='/connect';dest.searchParams.set('ticket',details.ticket);
  socket=new WebSocket(dest.href);$('live-pvp-connect').disabled=true;
  socket.onopen=()=>status('Connected. Finding another live player…');
  socket.onclose=()=>{$('live-pvp-connect').disabled=false;roundActive=false;status('Connection closed. Reconnect to try again.')};
  socket.onerror=()=>status('Connection error. Please reconnect.');
  root.IDLE_PVP_ARENA?.attach(socket);
  socket.onmessage=e=>{try{const msg=JSON.parse(e.data);if(msg.type==='hand'){root.IDLE_PVP_ARENA?.open(msg.opponent)}if(['hand','round_result','finished','locked','opponent_locked','ping'].includes(msg.type))return;handle(msg)}catch{status('Match message error')}};
 }catch(e){status(e.message);$('live-pvp-connect').disabled=false}
}
function play(id){
 if(!roundActive||socket?.readyState!==1)return;
 socket.send(JSON.stringify({type:'play',id}));roundActive=false;
 document.querySelectorAll('#live-hand button').forEach(x=>x.disabled=true);
 status('Card locked. Waiting for the other player…');
}
async function animate(msg){
 const display=$('live-battle-replay');display.replaceChildren();
 const headline=document.createElement('div');headline.className='live-round-heading';
 headline.textContent='ROUND '+msg.round+' · '+msg.cards[0].id+' VS '+msg.cards[1].id;display.append(headline);
 drawCards($('live-round-cards'),msg.cards);
 for(const hit of msg.log){
  const line=document.createElement('div');line.className='live-hit';
  line.textContent=(hit.actor===0?'YOUR CARD':'RIVAL')+'  '+(hit.critical?'CRIT ×2 · ':'')+hit.damage+' DMG · '+hit.hp+' HP';
  display.append(line);await new Promise(resolve=>setTimeout(resolve,450));
 }
 const end=document.createElement('strong');end.textContent=msg.winner==='draw'?'DRAW':msg.winner===0?'ROUND WON':'ROUND LOST';display.append(end);
 $('live-score').textContent=msg.score.join(' - ');
 if(socket?.readyState===1)socket.send(JSON.stringify({type:'ready'}));
}
function handle(msg){
 if(msg.type==='waiting')status('In matchmaking queue…');
 if(msg.type==='error')status(msg.message);
 if(msg.type==='opponent_left')status('Opponent disconnected. Waiting for another player…');
 if(msg.type==='locked')status('Card selected. Waiting for rival…');
 if(msg.type==='hand'){roundActive=true;status('ROUND '+msg.round+' · Pick one of your three cards against '+msg.opponent);$('live-hand-title').textContent='YOUR HAND · ROUND '+msg.round;drawCards($('live-hand'),msg.hand,true)}
 if(msg.type==='round_result'){roundActive=false;animate(msg)}
 if(msg.type==='finished'){roundActive=false;status('MATCH FINISHED · '+(msg.winner==='you'?'VICTORY':msg.winner==='draw'?'DRAW':'DEFEAT'));$('live-hand').replaceChildren();$('live-pvp-connect').disabled=false}
}
async function setSession(user,request){
 uid=user?.uid||null;api=request||null;
 if(socket){socket.close();socket=null}
 $('live-pvp-auth-hint').hidden=Boolean(uid);$('live-pvp-content').hidden=!uid;
 if(!uid){saved=[];dirty=true;updateDeck(getDraft());return}
 try{const sessionUid=uid;const result=await api('pvp/deck');if(uid!==sessionUid)return;
  saved=layout.cards(validDeck(result.cards));loaded=true;dirty=false;
  const local=validDeck(getDraft());
  deck=JSON.stringify(layout.cards(local))===JSON.stringify(saved)?local:validDeck(saved);
  setDraft();renderDeck();status('Your saved deck is ready. Edit it in Cards.');
 }catch(e){deck=validDeck(getDraft());dirty=true;renderDeck();status('Deck unavailable: '+e.message)}
}
function setup(){
 deck=validDeck(getDraft());renderDeck();renderCardControls();
 $('cards-deck-save').addEventListener('click',async()=>{
  if(!api){setDraft();deckStatus('Deck saved on this device. Sign in from Profile to save online.');return}
  if(!selected().length){deckStatus('Add at least one card for beta testing.');return}
  const requested=selected();
  try{deckStatus('Saving deck…');const result=await api('pvp/deck','PUT',{cards:requested});
   saved=result.cards;dirty=JSON.stringify(selected())!==JSON.stringify(saved);renderDeck();
   if(!dirty){deckStatus('✓ Deck saved to your account');status('Deck updated. Ready for live matchmaking.')}
  }catch(e){setDraft();deckStatus('Deck saved on this device only. Cloud: '+e.message)}
 });
 $('live-deck-edit').addEventListener('click',()=>{document.querySelector('[data-nav="cards"]')?.click();setTimeout(()=>$('deck-builder').scrollIntoView({block:'start',behavior:'smooth'}),50)});
 root.IDLE_PVP_ARENA?.setup();
 $('live-pvp-connect').addEventListener('click',begin);
 $('live-pvp-disconnect').addEventListener('click',()=>{if(socket)socket.close();socket=null;$('live-pvp-connect').disabled=false;status('Disconnected')});
}
root.IDLE_LIVE_PVP={setup,setSession,insert,renderDeck,renderCardControls,refreshLabels};
})(window);

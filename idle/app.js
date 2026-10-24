(()=>{
'use strict';
const $=id=>document.getElementById(id);
const heroes=window.IDLE_HERO_CATALOG||[];
const STORAGE='idle-kardrune-demo-v1';
const AVATARS=Object.freeze({player:'Player',guard:'Guard',vassal:'Vassal',king:'King'});
const avatarImage=id=>'./media/avatars/avatar_'+id+'.webp';
const rules=window.IDLE_GAME_RULES;
const combat=window.IDLE_COMBAT_RULES;
const cardId=(hero,stage)=>hero.id+':'+stage;
const cardImage=(hero,stage)=>'./media/cards/'+hero.stages[stage-1];
const cardVideo=(hero,stage)=>hero.loops[stage-1]?'./media/animations/'+hero.loops[stage-1]:null;
const initial=()=>({name:'Runebearer',avatar:'player',shards:1500,owned:['sam:1','lira:1','rhea:1'],active:'sam:1',duels:0,wins:0,pulls:0,practiceDaily:{day:'',count:0},attacks:{'sam:1':50,'lira:1':50,'rhea:1':50},crits:{'sam:1':10,'lira:1':10,'rhea:1':10},pendingDuplicate:null});
function normalizeAttacks(values,owned){
 const obj=values&&typeof values==='object'&&!Array.isArray(values)?values:{};
 return Object.fromEntries(owned.map(id=>[id,combat.isAttack(obj[id])?obj[id]:combat.legacyAttack(id)]));
}
function normalizeCrits(values,owned){
 const obj=values&&typeof values==='object'&&!Array.isArray(values)?values:{};
 return Object.fromEntries(owned.map(id=>[id,combat.isCrit(obj[id])?obj[id]:combat.legacyCrit(id)]));
}
function normalizePending(v,owned){
 if(!v||typeof v!=='object'||!owned.includes(v.id)||!combat.isAttack(v.attack))return null;
 return {id:v.id,attack:v.attack,crit:combat.isCrit(v.crit)?v.crit:combat.legacyCrit(v.id+':duplicate')};
}
function migrate(v){
  const base=initial();if(!v||typeof v!=='object')return base;
  const ids=Array.isArray(v.owned)?v.owned.map(id=>String(id).includes(':')?String(id):String(id)+':1'):[];
  const valid=ids.filter(id=>{const [h,s]=id.split(':');return heroes.some(hero=>hero.id===h)&&Number(s)>=1&&Number(s)<=3;});
  const active=String(v.active||base.active);const normalized=active.includes(':')?active:active+':1';
  const owned=[...new Set(valid.length?valid:base.owned)];
  return {name:typeof v.name==='string'?v.name.slice(0,20):base.name,avatar:Object.prototype.hasOwnProperty.call(AVATARS,v.avatar)?v.avatar:base.avatar,shards:Number.isFinite(v.shards)?Math.max(0,Math.floor(v.shards)):base.shards,
    owned,active:owned.includes(normalized)?normalized:owned[0],duels:rules.safeCount(v.duels),wins:rules.safeCount(v.wins),pulls:rules.safeCount(v.pulls),practiceDaily:rules.dailyRewardState(v.practiceDaily),attacks:normalizeAttacks(v.attacks,owned),crits:normalizeCrits(v.crits,owned),pendingDuplicate:normalizePending(v.pendingDuplicate,owned)};
}
function load(){try{return migrate(JSON.parse(localStorage.getItem(STORAGE)))}catch{return initial()}}
let state=load(),filter='all',grouped=false,installEvent=null,pulling=false;
let opponent=null,liveBattle=null,battleTimer=null,pendingDuplicate=state.pendingDuplicate?{...state.pendingDuplicate,...itemById(state.pendingDuplicate.id)}:null;
function persist(){try{localStorage.setItem(STORAGE,JSON.stringify(state));return true}catch{notify('Local progress could not be saved');return false}}
function notify(message){const el=$('toast');el.textContent=message;el.hidden=false;clearTimeout(notify.t);notify.t=setTimeout(()=>el.hidden=true,2800)}
function ownedCards(){return heroes.flatMap(hero=>[1,2,3].filter(stage=>state.owned.includes(cardId(hero,stage))).map(stage=>({hero,stage})))}
function itemById(id){const [key,level]=String(id).split(':');const hero=heroes.find(h=>h.id===key);return hero?{hero,stage:Math.max(1,Math.min(3,Number(level)||1))}:null}
function displayStats(stage,attack,crit){
 const sanitizedCrit=combat.isCrit(crit)?crit:0;
 const bar=elem('div','battle-card-stats');
 const atk=elem('span','card-atk',String(attack));
 atk.title='ATK '+attack;atk.setAttribute('aria-label','ATK '+attack);
 const critical=elem('span','card-crit',sanitizedCrit+'%');
 critical.title='Critical chance '+sanitizedCrit+'% · Double damage';
 critical.setAttribute('aria-label','Critical chance '+sanitizedCrit+' percent');
 const hp=elem('span','card-hp',String(combat.hpForStage(stage)));
 hp.title='HP '+combat.hpForStage(stage);hp.setAttribute('aria-label','HP '+combat.hpForStage(stage));
 bar.append(atk,critical,hp);return bar;
}
function openDialog(node){
  const d=$('game-dialog');
  const isSummon=node.classList.contains('summon-reveal');
  d.classList.toggle('summon-dialog',isSummon);
  d.classList.toggle('duplicate-dialog',node.classList.contains('duplicate-compare'));
  $('dialog-done').textContent=isSummon&&node.dataset.preview==='true'?'BACK TO SUMMON':'CONTINUE';
  $('dialog-content').replaceChildren(node);
  if(!d.open)d.showModal();
}
function elem(name,className,text){const n=document.createElement(name);if(className)n.className=className;if(text!==undefined)n.textContent=text;return n}
function reveal(hero,stage,dupe,preview){
  const wrap=elem('div','summon-reveal');
  wrap.dataset.preview=String(preview);
  wrap.dataset.stage=String(stage);

  const eyebrow=elem('div','summon-reveal-eyebrow',preview?'✦ SUMMON PREVIEW ✦':dupe?'✦ RUNIC ECHO ✦':'✦ HERO SUMMONED ✦');
  const media=elem('div','summon-reveal-media');
  const videoSrc=cardVideo(hero,stage);
  let video=null;
  if(videoSrc){
    // One animated asset only; don't overlay the static card artwork or a poster.
    video=elem('video','summon-reveal-video');
    video.src=videoSrc;
    video.autoplay=true;
    video.muted=true;
    video.loop=true;
    video.playsInline=true;
    video.preload='metadata';
    video.setAttribute('webkit-playsinline','');
    video.setAttribute('aria-label',hero.name+' Stage '+stage+' summon animation');
    // New-card reveal remains square even for landscape video files.
    const errorText=elem('p','summon-video-fallback','The summon animation could not be loaded.');
    errorText.hidden=true;
    video.addEventListener('error',()=>{video.hidden=true;errorText.hidden=false});
    media.append(video,errorText);
  }else{
    media.append(elem('p','summon-video-fallback','Animation coming soon for '+hero.name+' Stage '+stage+'.'));
  }

  const info=elem('div','summon-reveal-info');
  const stageBadge=elem('span','summon-reveal-stage','STAGE '+stage);
  const name=elem('h2','summon-reveal-name',hero.name.toUpperCase());
  name.id='dialog-title';
  const subtitle=elem('p','summon-reveal-caption',
    preview?'Preview of this hero evolution':
      dupe?'Duplicate card · 100 demo Shards refunded.':
      'NEW CARD UNLOCKED · Saved to your collection.');
  info.append(stageBadge,name,subtitle);
  wrap.append(eyebrow,media,info);
  openDialog(wrap);
  if(video)video.play().catch(()=>{video.controls=true});
}
function makeCard(hero,stage){
 const id=cardId(hero,stage),has=state.owned.includes(id),selected=state.active===id;
 const box=elem('article','hero-card card-stage-'+stage+(has?'':' locked'));
 const image=elem('div','hero-image');const img=elem('img');img.src=cardImage(hero,stage);img.alt=hero.name+' Stage '+stage;img.loading='lazy';image.append(img);if(has)image.append(displayStats(stage,state.attacks[id],state.crits[id]));if(!has){const mystery=elem('span','mystery-mark','?');mystery.setAttribute('aria-hidden','true');image.append(mystery)}box.append(image);
 box.append(elem('div','rarity-tag','STAGE '+stage+' · '+hero.element.toUpperCase()),elem('h3','',hero.name));
 box.append(elem('p','',has?'ATK '+state.attacks[id]+' · CRIT '+state.crits[id]+'% · HP '+combat.hpForStage(stage):'NOT COLLECTED'));
 if(selected)box.append(elem('span','hero-selected','✦ SELECTED CHAMPION'));
 if(has){box.tabIndex=0;box.role='button';box.title='Select '+hero.name+' Stage '+stage;const select=()=>{if(liveBattle)return notify('Finish your duel first');state.active=id;opponent=null;persist();render();notify(hero.name+' Stage '+stage+' selected')};box.addEventListener('click',select);box.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();select()}})}
 return box;
}
function renderCards(){
 const grid=$('hero-grid');grid.replaceChildren();const all=heroes.flatMap(hero=>[1,2,3].map(stage=>({hero,stage}))).filter(x=>filter==='all'||(filter==='owned'?state.owned.includes(cardId(x.hero,x.stage)):!state.owned.includes(cardId(x.hero,x.stage))));
 if(grouped){for(const hero of heroes){const cards=all.filter(x=>x.hero===hero);if(!cards.length)continue;const heading=elem('h2','card-group-heading',hero.name+' · 3 STAGES');grid.append(heading);cards.forEach(x=>grid.append(makeCard(x.hero,x.stage)))}}else all.forEach(x=>grid.append(makeCard(x.hero,x.stage)));
 const owned=ownedCards().length,total=heroes.length*3;
 $('owned-count').innerHTML=owned+' <span>/ '+total+' CARDS</span>';
 $('collection-bar').style.width=(owned/total*100)+'%';
 $('stat-cards').textContent=owned;
}
function renderRoster(){
 const grid=$('summon-roster-grid');grid.replaceChildren();
 for(const hero of heroes){const button=elem('button','summon-roster-card');button.type='button';const img=elem('img');img.src=cardImage(hero,1);img.loading='lazy';img.alt=hero.name;button.append(img,elem('strong','',hero.name),elem('small','',''));button.lastChild.textContent='STAGES 1–3';button.addEventListener('click',()=>previewHero(hero));grid.append(button)}
}
function previewHero(hero){
 const wrap=elem('div','hero-preview');wrap.append(elem('h2','',hero.name+' · All stages'));
 const choices=elem('div','hero-preview-stages');
 for(let stage=1;stage<=3;stage++){const b=elem('button','hero-preview-choice');b.type='button';const img=elem('img');img.src=cardImage(hero,stage);img.alt=hero.name+' stage '+stage;b.append(img,elem('span','',''));b.lastChild.textContent='STAGE '+stage;b.addEventListener('click',()=>{const d=$('game-dialog');d.close();reveal(hero,stage,false,true)});choices.append(b)}
 wrap.append(choices,elem('p','','Tap a stage to preview the matching summon animation.'));
 openDialog(wrap);
}
function render(){
 $('wallet-shards').textContent=state.shards.toLocaleString('en-US');
 $('stat-duels').textContent=state.duels;$('stat-wins').textContent=state.wins;$('stat-pulls').textContent=state.pulls;
 state.practiceDaily=rules.dailyRewardState(state.practiceDaily);
 $('practice-rewards-left').textContent=String(rules.DAILY_REWARD_LIMIT-state.practiceDaily.count);
 $('profile-display-name').textContent=state.name;$('name-input').value=state.name;
 $('profile-avatar-image').src=avatarImage(state.avatar);
 $('profile-avatar-image').alt=AVATARS[state.avatar]+' avatar';
 document.querySelectorAll('[data-avatar]').forEach(button=>{
   const selected=button.dataset.avatar===state.avatar;
   button.classList.toggle('selected',selected);
   button.setAttribute('aria-pressed',String(selected));
 });
 const owned=ownedCards(),select=$('active-hero-select');select.replaceChildren();
 owned.forEach(({hero,stage})=>{const op=elem('option','',hero.name+' · Stage '+stage);op.value=cardId(hero,stage);select.append(op)});
 if(!owned.some(({hero,stage})=>cardId(hero,stage)===state.active))state.active=owned[0]?cardId(owned[0].hero,owned[0].stage):'sam:1';
 select.value=state.active;const current=itemById(state.active);
 $('duel-player-art').src=cardImage(current.hero,current.stage);$('duel-player-name').textContent=current.hero.name+' · S'+current.stage;
 if(!liveBattle){renderOpponent();$('player-health-fill').style.width='100%'}
 $('duel-player-attack').textContent=state.attacks[state.active];
 $('duel-player-crit').textContent=state.crits[state.active]+'%';
 $('duel-player-maxhp').textContent=combat.hpForStage(current.stage);
 $('duel-player-hp').textContent=liveBattle?liveBattle.player.hp:combat.hpForStage(current.stage);
 renderCards();
}
function go(route){if(!['tournament','cards','summon','profile'].includes(route))route='tournament';document.querySelectorAll('.screen').forEach(el=>el.hidden=el.id!=='screen-'+route);document.querySelectorAll('[data-nav]').forEach(el=>{const a=el.dataset.nav===route;el.classList.toggle('active',a);if(a)el.setAttribute('aria-current','page');else el.removeAttribute('aria-current')});if(location.hash!=='#'+route)history.replaceState(null,'','#'+route);scrollTo(0,0)}
document.querySelectorAll('[data-nav]').forEach(el=>el.addEventListener('click',()=>go(el.dataset.nav)));
addEventListener('hashchange',()=>go(location.hash.slice(1)));
document.querySelectorAll('[data-filter]').forEach(el=>el.addEventListener('click',()=>{filter=el.dataset.filter;document.querySelectorAll('[data-filter]').forEach(b=>b.classList.toggle('active',b===el));renderCards()}));
$('card-view-grid').addEventListener('click',()=>{grouped=false;$('card-view-grid').classList.add('active');$('card-view-heroes').classList.remove('active');renderCards()});
$('card-view-heroes').addEventListener('click',()=>{grouped=true;$('card-view-heroes').classList.add('active');$('card-view-grid').classList.remove('active');renderCards()});
$('active-hero-select').addEventListener('change',e=>{if(liveBattle)return;state.active=e.target.value;opponent=null;persist();render()});
function renderOpponent(){
 if(!opponent)opponent=combat.pickEnemy(heroes,itemById(state.active).stage);
 const hero=heroes.find(x=>x.id===opponent.id);
 $('duel-enemy-art').src=cardImage(hero,opponent.stage);
 $('duel-enemy-name').textContent=opponent.name+' · S'+opponent.stage;
 $('duel-enemy-attack').textContent=opponent.attack;
 $('duel-enemy-crit').textContent=opponent.crit+'%';
 $('duel-enemy-maxhp').textContent=opponent.maxHp;
 $('duel-enemy-hp').textContent=liveBattle?liveBattle.enemy.hp:opponent.maxHp;
 $('enemy-health-fill').style.width=((liveBattle?liveBattle.enemy.hp:opponent.maxHp)/opponent.maxHp*100)+'%';
}
function updateBattle(){
 if(!liveBattle)return;
 for(const side of ['player','enemy']){
   const unit=liveBattle[side];
   $('duel-'+side+'-hp').textContent=unit.hp;
   $(side==='player'?'player-health-fill':'enemy-health-fill').style.width=(unit.hp/unit.maxHp*100)+'%';
 }
 const last=liveBattle.lastHit;
 $('battle-live-status').textContent=last?(last.actor==='player'?'You hit':'Opponent hits')+' for '+last.damage+' damage'+(last.critical?' · CRITICAL ×2!':''): 'Battle in progress…';
 $('battle-turn-counter').textContent=String(liveBattle.hits);
}
function endBattle(){
 if(!liveBattle||liveBattle.status!=='finished')return;
 const win=liveBattle.winner==='player';
 state.duels++;if(win)state.wins++;
 const daily=rules.dailyRewardState(state.practiceDaily);
 const rewarded=daily.count<rules.DAILY_REWARD_LIMIT;
 const reward=rewarded?(win?100:35):0;
 if(rewarded)daily.count++;
 state.practiceDaily=daily;state.shards+=reward;
 persist();clearInterval(battleTimer);battleTimer=null;
 $('practice-button').disabled=false;
 $('reroll-enemy').disabled=false;
 $('active-hero-select').disabled=false;
 $('practice-button').textContent='⚔ START ANOTHER DUEL';
 $('battle-live-status').textContent=(win?'VICTORY!':'DEFEAT!')+(reward?' · +'+reward+' Shards':' · Daily rewards exhausted');
 const wrap=elem('div','');
 wrap.append(elem('h2','',win?'TRAINING VICTORY!':'TRAINING DEFEAT'),elem('p','',reward?'Earned '+reward+' demo Rune Shards.':'Daily rewards exhausted; come back tomorrow for more.'));
 liveBattle=null;
 render();
 openDialog(wrap);
}
function startPractice(){
 if(liveBattle)return;
 const current=itemById(state.active);
 if(!current)return notify('Choose a champion');
 if(!opponent)renderOpponent();
 liveBattle=combat.newBattle({id:current.hero.id,name:current.hero.name,stage:current.stage,attack:state.attacks[state.active],crit:state.crits[state.active]},opponent);
 $('practice-button').disabled=true;
 $('reroll-enemy').disabled=true;
 $('active-hero-select').disabled=true;
 $('practice-button').textContent='DUEL IN PROGRESS…';
 $('battle-live-status').textContent='Battle started — turns alternate automatically';
 $('battle-turn-counter').textContent='0';
 updateBattle();
 battleTimer=setInterval(()=>{
  liveBattle=combat.nextTurn(liveBattle);
  updateBattle();
  if(liveBattle.status==='finished')endBattle();
 },combat.TURN_MS);
}
$('practice-button').addEventListener('click',startPractice);
$('reroll-enemy').addEventListener('click',()=>{
 if(liveBattle)return;
 opponent=combat.pickEnemy(heroes,itemById(state.active).stage);
 renderOpponent();
 $('battle-live-status').textContent='New random opponent ready';
});

function summon(featured){
 if(pulling)return;const cost=featured?600:300;
 if(state.shards<cost){notify('Not enough Rune Shards');return}
 pulling=true;const r=Math.random(),stage=featured?(r<.60?1:r<.90?2:3):(r<.78?1:r<.97?2:3);
 // Featured: 35% chance to select Dren; otherwise all nine equally eligible.
 let hero=featured&&Math.random()<.35?heroes.find(h=>h.id==='dren'):heroes[Math.floor(Math.random()*heroes.length)];
 if(!hero){pulling=false;return}
 state.shards-=cost;state.pulls++;
 const id=cardId(hero,stage),duplicate=state.owned.includes(id);
 const attack=combat.rollAttack();
 const crit=combat.rollCrit();
 if(duplicate){
   pendingDuplicate={id,attack,crit,hero,stage};
   state.pendingDuplicate={id,attack,crit};
   persist();render();showDuplicate();
 }else{
   state.owned.push(id);state.attacks[id]=attack;state.crits[id]=crit;
   persist();render();reveal(hero,stage,false,false);
 }
 pulling=false;
}
function duplicateCardPanel(hero,stage,attack,crit,label,newPull){
 const panel=elem('article','duplicate-card-panel'+(newPull?' is-new':''));
 const title=elem('div','duplicate-card-title',label);
 const art=elem('div','duplicate-card-art hero-image');
 const picture=elem('img','');
 picture.src=cardImage(hero,stage);
 picture.alt=hero.name+' Stage '+stage+' card';
 art.append(picture,displayStats(stage,attack,crit));
 panel.append(title,art,elem('div','duplicate-card-name',hero.name+' · S'+stage));
 const stats=elem('div','duplicate-card-summary','ATK '+attack+' · CRIT '+crit+'% · HP '+combat.hpForStage(stage));
 panel.append(stats);
 return panel;
}
function showDuplicate(){
 if(!pendingDuplicate)return;
 const {id,attack,crit,hero,stage}=pendingDuplicate;
 const wrap=elem('div','duplicate-compare');
 const header=elem('div','duplicate-heading');
 const title=elem('h2','','DUPLICATE FOUND');
 title.id='dialog-title';
 header.append(elem('span','duplicate-kicker','✦ TWO CARDS · ONE SLOT ✦'),title,
   elem('p','','Compare both cards. Keep the current one, or replace it with this pull.'));
 wrap.append(header);
 const pair=elem('div','duplicate-card-pair');
 pair.append(
   duplicateCardPanel(hero,stage,state.attacks[id],state.crits[id],'YOUR CARD',false),
   duplicateCardPanel(hero,stage,attack,crit,'NEW PULL',true)
 );
 wrap.append(pair);
 const actions=elem('div','duplicate-actions');
 for(const [caption,replace] of [['KEEP CURRENT',false],['KEEP NEW',true]]){
  const button=elem('button',replace?'gold-button':'dark-button',caption);
  button.type='button';
  button.addEventListener('click',()=>{
   if(!pendingDuplicate)return;
   // One decision, persisted atomically with both battle statistics.
   if(replace){
     state.attacks[id]=attack;
     state.crits[id]=crit;
   }else{
     state.shards+=100; // Existing duplicate discard reward
   }
   pendingDuplicate=null;
   state.pendingDuplicate=null;
   persist();render();
   $('game-dialog').close();
   notify(replace?'New card equipped · previous stats discarded':'Current card kept · new pull discarded · +100 Shards');
  });
  actions.append(button);
 }
 wrap.append(actions,elem('p','duplicate-footnote','HP depends on Stage. Discarding the new duplicate rewards 100 demo Shards.'));
 openDialog(wrap);
 $('dialog-done').hidden=true;
}
$('summon-standard').addEventListener('click',()=>summon(false));
$('summon-featured').addEventListener('click',()=>summon(true));
document.querySelectorAll('[data-avatar]').forEach(button=>button.addEventListener('click',()=>{
 const id=button.dataset.avatar;
 if(!Object.prototype.hasOwnProperty.call(AVATARS,id)||id===state.avatar)return;
 state.avatar=id;
 persist();
 render();
 notify(AVATARS[id]+' avatar selected');
}));
$('name-form').addEventListener('submit',e=>{e.preventDefault();const value=$('name-input').value.trim().replace(/\s+/g,' ');if(value.length<2)return notify('Name needs at least two characters');state.name=value.slice(0,20);persist();render();notify('Name saved on this device')});
$('reset-button').addEventListener('click',()=>{if(!confirm('Reset all local Idle KardRune progress on this device?'))return;state=initial();persist();filter='all';document.querySelectorAll('[data-filter]').forEach(b=>b.classList.toggle('active',b.dataset.filter==='all'));render();go('profile');notify('Local demo reset')});
$('dialog-close').addEventListener('click',()=>{if(pendingDuplicate)return notify('Choose KEEP or REPLACE');$('game-dialog').close()});
$('dialog-done').addEventListener('click',()=>{if(pendingDuplicate)return;$('game-dialog').close()});
$('game-dialog').addEventListener('click',e=>{if(e.target===$('game-dialog')&&!pendingDuplicate)e.target.close()});
$('game-dialog').addEventListener('cancel',e=>{if(pendingDuplicate)e.preventDefault()});
$('game-dialog').addEventListener('close',()=>{$('dialog-done').hidden=false;if(pendingDuplicate){notify('Choose KEEP or REPLACE to finish the pull');setTimeout(showDuplicate,0)}for(const v of $('dialog-content').querySelectorAll('video')){v.pause();v.removeAttribute('src');v.load()}});
addEventListener('beforeinstallprompt',e=>{e.preventDefault();installEvent=e;$('install-help').textContent='Ready to add to your home screen.'});
$('install-button').addEventListener('click',async()=>{if(installEvent){installEvent.prompt();await installEvent.userChoice;installEvent=null}else notify('Use Safari Share or Chrome menu → Add to Home Screen')});
if('serviceWorker' in navigator)addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(()=>{}));
renderRoster();render();go(location.hash.slice(1)||'tournament');
if(pendingDuplicate)showDuplicate();
const param=new URLSearchParams(location.search).get('install');
if(param==='ios'||param==='android'){const wrap=elem('div');wrap.append(elem('h2','','INSTALL IDLE KARDRUNE'),elem('p','',param==='ios'?'In Safari tap Share → Add to Home Screen.':'In Chrome tap ⋮ → Install app or Add to Home Screen.'));openDialog(wrap);history.replaceState(null,'',location.pathname+(location.hash||''))}
})();
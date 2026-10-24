(()=>{
'use strict';
const $=id=>document.getElementById(id);
const heroes=window.IDLE_HERO_CATALOG||[];
const STORAGE='idle-kardrune-demo-v1';
const AVATARS=Object.freeze({player:'Player',guard:'Guard',vassal:'Vassal',king:'King'});
const avatarImage=id=>'./media/avatars/avatar_'+id+'.webp';
const rules=window.IDLE_GAME_RULES;
const cardId=(hero,stage)=>hero.id+':'+stage;
const cardImage=(hero,stage)=>'./media/cards/'+hero.stages[stage-1];
const cardVideo=(hero,stage)=>hero.loops[stage-1]?'./media/animations/'+hero.loops[stage-1]:null;
const initial=()=>({name:'Runebearer',avatar:'player',shards:1500,owned:['sam:1','lira:1','rhea:1'],active:'sam:1',duels:0,wins:0,pulls:0,practiceDaily:{day:'',count:0}});
function migrate(v){
  const base=initial();if(!v||typeof v!=='object')return base;
  const ids=Array.isArray(v.owned)?v.owned.map(id=>String(id).includes(':')?String(id):String(id)+':1'):[];
  const valid=ids.filter(id=>{const [h,s]=id.split(':');return heroes.some(hero=>hero.id===h)&&Number(s)>=1&&Number(s)<=3;});
  const active=String(v.active||base.active);const normalized=active.includes(':')?active:active+':1';
  const owned=[...new Set(valid.length?valid:base.owned)];
  return {name:typeof v.name==='string'?v.name.slice(0,20):base.name,avatar:Object.prototype.hasOwnProperty.call(AVATARS,v.avatar)?v.avatar:base.avatar,shards:Number.isFinite(v.shards)?Math.max(0,Math.floor(v.shards)):base.shards,
    owned,active:owned.includes(normalized)?normalized:owned[0],duels:rules.safeCount(v.duels),wins:rules.safeCount(v.wins),pulls:rules.safeCount(v.pulls),practiceDaily:rules.dailyRewardState(v.practiceDaily)};
}
function load(){try{return migrate(JSON.parse(localStorage.getItem(STORAGE)))}catch{return initial()}}
let state=load(),filter='all',grouped=false,installEvent=null,pulling=false;
function persist(){try{localStorage.setItem(STORAGE,JSON.stringify(state));return true}catch{notify('Local progress could not be saved');return false}}
function notify(message){const el=$('toast');el.textContent=message;el.hidden=false;clearTimeout(notify.t);notify.t=setTimeout(()=>el.hidden=true,2800)}
function ownedCards(){return heroes.flatMap(hero=>[1,2,3].filter(stage=>state.owned.includes(cardId(hero,stage))).map(stage=>({hero,stage})))}
function itemById(id){const [key,level]=String(id).split(':');const hero=heroes.find(h=>h.id===key);return hero?{hero,stage:Math.max(1,Math.min(3,Number(level)||1))}:null}
function openDialog(node){
  const d=$('game-dialog');
  const isSummon=node.classList.contains('summon-reveal');
  d.classList.toggle('summon-dialog',isSummon);
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
    video.addEventListener('loadedmetadata',()=>{
      if(video.videoWidth>0&&video.videoHeight>0){
        media.style.aspectRatio=video.videoWidth+' / '+video.videoHeight;
      }
    });
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
 const image=elem('div','hero-image');const img=elem('img');img.src=cardImage(hero,stage);img.alt=hero.name+' Stage '+stage;img.loading='lazy';image.append(img);if(!has){const mystery=elem('span','mystery-mark','?');mystery.setAttribute('aria-hidden','true');image.append(mystery)}box.append(image);
 box.append(elem('div','rarity-tag','STAGE '+stage+' · '+hero.element.toUpperCase()),elem('h3','',hero.name));
 box.append(elem('p','',has?'POWER '+(hero.power+(stage-1)*18):'NOT COLLECTED'));
 if(selected)box.append(elem('span','hero-selected','✦ SELECTED CHAMPION'));
 if(has){box.tabIndex=0;box.role='button';box.title='Select '+hero.name+' Stage '+stage;const select=()=>{state.active=id;persist();render();notify(hero.name+' Stage '+stage+' selected')};box.addEventListener('click',select);box.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();select()}})}
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
 renderCards();
}
function go(route){if(!['tournament','cards','summon','profile'].includes(route))route='tournament';document.querySelectorAll('.screen').forEach(el=>el.hidden=el.id!=='screen-'+route);document.querySelectorAll('[data-nav]').forEach(el=>{const a=el.dataset.nav===route;el.classList.toggle('active',a);if(a)el.setAttribute('aria-current','page');else el.removeAttribute('aria-current')});if(location.hash!=='#'+route)history.replaceState(null,'','#'+route);scrollTo(0,0)}
document.querySelectorAll('[data-nav]').forEach(el=>el.addEventListener('click',()=>go(el.dataset.nav)));
addEventListener('hashchange',()=>go(location.hash.slice(1)));
document.querySelectorAll('[data-filter]').forEach(el=>el.addEventListener('click',()=>{filter=el.dataset.filter;document.querySelectorAll('[data-filter]').forEach(b=>b.classList.toggle('active',b===el));renderCards()}));
$('card-view-grid').addEventListener('click',()=>{grouped=false;$('card-view-grid').classList.add('active');$('card-view-heroes').classList.remove('active');renderCards()});
$('card-view-heroes').addEventListener('click',()=>{grouped=true;$('card-view-heroes').classList.add('active');$('card-view-grid').classList.remove('active');renderCards()});
$('active-hero-select').addEventListener('change',e=>{state.active=e.target.value;persist();render()});
$('practice-button').addEventListener('click',()=>{const current=itemById(state.active);if(!current)return notify('Choose a champion');const result=rules.resolvePractice(state.practiceDaily,current.hero.power,current.stage,Math.random());state.duels++;if(result.win)state.wins++;state.shards+=result.reward;state.practiceDaily=result.daily;persist();render();const wrap=elem('div','');wrap.append(elem('h2','',result.win?'TRAINING VICTORY!':'TRAINING COMPLETE'),elem('p','',result.reward?current.hero.name+' earned '+result.reward+' demo Rune Shards.':'Daily reward limit reached. Keep practicing; Shards reset at local midnight.'));openDialog(wrap)});
function summon(featured){
 if(pulling)return;const cost=featured?600:300;
 if(state.shards<cost){notify('Not enough Rune Shards');return}
 pulling=true;const r=Math.random(),stage=featured?(r<.60?1:r<.90?2:3):(r<.78?1:r<.97?2:3);
 // Featured: 35% chance to select Dren; otherwise all nine equally eligible.
 let hero=featured&&Math.random()<.35?heroes.find(h=>h.id==='dren'):heroes[Math.floor(Math.random()*heroes.length)];
 if(!hero){pulling=false;return}
 state.shards-=cost;state.pulls++;
 const id=cardId(hero,stage),duplicate=state.owned.includes(id);
 if(duplicate)state.shards+=100;else state.owned.push(id);
 persist();render();reveal(hero,stage,duplicate,false);pulling=false;
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
$('dialog-close').addEventListener('click',()=>$('game-dialog').close());
$('dialog-done').addEventListener('click',()=>$('game-dialog').close());
$('game-dialog').addEventListener('click',e=>{if(e.target===$('game-dialog'))e.target.close()});
$('game-dialog').addEventListener('close',()=>{for(const v of $('dialog-content').querySelectorAll('video')){v.pause();v.removeAttribute('src');v.load()}});
addEventListener('beforeinstallprompt',e=>{e.preventDefault();installEvent=e;$('install-help').textContent='Ready to add to your home screen.'});
$('install-button').addEventListener('click',async()=>{if(installEvent){installEvent.prompt();await installEvent.userChoice;installEvent=null}else notify('Use Safari Share or Chrome menu → Add to Home Screen')});
if('serviceWorker' in navigator)addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(()=>{}));
renderRoster();render();go(location.hash.slice(1)||'tournament');
const param=new URLSearchParams(location.search).get('install');
if(param==='ios'||param==='android'){const wrap=elem('div');wrap.append(elem('h2','','INSTALL IDLE KARDRUNE'),elem('p','',param==='ios'?'In Safari tap Share → Add to Home Screen.':'In Chrome tap ⋮ → Install app or Add to Home Screen.'));openDialog(wrap);history.replaceState(null,'',location.pathname+(location.hash||''))}
})();
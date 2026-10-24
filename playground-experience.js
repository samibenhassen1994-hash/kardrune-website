/* KardRune Playground experience. Reads a single manifest shared by every public tool. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const page = document.body.dataset.tool;
  const rand = max => {
    if (!Number.isSafeInteger(max) || max < 1 || max > 1000000) throw new RangeError('Invalid die');
    if (globalThis.crypto?.getRandomValues) {
      const buf = new Uint32Array(1);
      const ceil = Math.floor(4294967296 / max) * max;
      do { crypto.getRandomValues(buf); } while (buf[0] >= ceil);
      return buf[0] % max;
    }
    return Math.floor(Math.random() * max);
  };
  const text = (id, str) => { if ($(id)) $(id).textContent = String(str); };
  const clamp = (n,lo,hi) => Math.max(lo,Math.min(hi,n));
  const safe = id => String(id).replace(/[^a-z0-9_-]/gi,'_');
  const heroNames = ['Sam','Lira','Rhea','Dren','Tor','Aria','Kael','Neris','Nyra'];
  const getImage = url => new Promise((resolve,reject) => {const img=new Image();img.onload=()=>resolve(img);img.onerror=()=>reject(Error('Artwork unavailable'));img.src=url;});
  const assetReady = Promise.all([
    fetch('game-assets.json').then(r=>{if(!r.ok)throw Error('Asset manifest unavailable');return r.json();}),
    fetch('playground-characters.json').then(r=>{if(!r.ok)throw Error('Character manifest unavailable');return r.json();})
  ]).then(([assets, characters]) => ({assets, characters}));
  let database = null;
  const sheetCache = new Map();
  function getSheet(index) {
    if (!database) return Promise.reject(Error('Catalog not available'));
    if (!sheetCache.has(index)) sheetCache.set(index,getImage(database.assets.atlasNames[index]));
    return sheetCache.get(index);
  }
  function applyArt(el, key) {
    const {assets} = database || {};
    const item = assets?.entries[key];
    if (!item || !el) return false;
    el.dataset.gameArt = key;
    const {columns,rows,tileWidth,tileHeight,atlasNames}=assets;
    el.style.backgroundImage=`url("${atlasNames[item.sheet]}")`;
    el.style.backgroundSize=`${columns * 100}% ${rows * 100}%`;
    el.style.backgroundPosition=`${item.col / (columns-1) * 100}% ${item.row / (rows-1) * 100}%`;
    el.style.backgroundRepeat='no-repeat';
    el.style.aspectRatio=`${tileWidth}/${tileHeight}`;
    el.classList.add('game-art-ready');
    return true;
  }
  function refreshArtwork(root = document) {
    root.querySelectorAll('[data-game-art]').forEach(el=>applyArt(el,el.dataset.gameArt));
  }
  async function assetCanvasImage(key) {
    const {assets}=database;
    const item=assets.entries[key];
    if(!item)throw Error('Unknown artwork');
    const img=await getSheet(item.sheet);
    const canvas=document.createElement('canvas');
    canvas.width=assets.tileWidth;canvas.height=assets.tileHeight;
    canvas.getContext('2d').drawImage(img,item.col*canvas.width,item.row*canvas.height,canvas.width,canvas.height,0,0,canvas.width,canvas.height);
    return canvas.toDataURL('image/png');
  }
  const setResultArt=(id,key)=>{const el=$(id);if(el)applyArt(el,key);};

  function initWiki() {
    const items=[...document.querySelectorAll('.wiki-entry')];
    const filter=()=>{
      const query=$('wiki-search').value.trim().toLowerCase();const kind=$('wiki-kind').value;
      let count=0;
      items.forEach(item=>{
        const matches=(kind==='all'||kind===item.dataset.kind)&&(!query||(item.dataset.search||'').includes(query));
        item.hidden=!matches;if(matches)count++;
      });
      $('wiki-empty').hidden=count>0;
    };
    $('wiki-search')?.addEventListener('input',filter);
    $('wiki-kind')?.addEventListener('change',filter);
    document.querySelectorAll('.wiki-stage-buttons').forEach(group=>{
      group.addEventListener('click',event=>{
        const btn=event.target.closest('[data-stage-art]');if(!btn)return;
        const card=group.closest('.wiki-entry');const art=card.querySelector('.wiki-art-panel');
        applyArt(art,btn.dataset.stageArt);
        group.querySelectorAll('button').forEach(b=>{let active=b===btn;b.classList.toggle('selected',active);b.setAttribute('aria-pressed',String(active));});
        art.classList.remove('evolution-pop');void art.offsetWidth;art.classList.add('evolution-pop');
      });
    });
    filter();
  }

  function initDice() {
    const form=$('dice-form');if(!form)return;
    const mode=$('dice-mode');const history=[];
    const canvas=$('dice-canvas');const ctx=canvas?.getContext('2d');
    const spinURL='assets/playground/d20-spin.webp';
    const settleURL=n=>`assets/playground/d20-settle_${String(n).padStart(2,'0')}.webp`;
    const rollButton=form.querySelector('button[type=submit]');
    let busy=false;
    let lastFace=1;
    const historyList=$('dice-history');
    function setMode(){const d20=+$('dice-type').value===20 && +$('dice-count').value===1;if(!d20)mode.value='normal';mode.disabled=!d20;mode.title=d20?'':'Advantage requires one D20';}
    ['dice-type','dice-count'].forEach(k=>$(k).addEventListener('input',setMode));setMode();
    function draw(img,frame,cols=6,cell=256){
      if(!ctx)return;
      ctx.clearRect(0,0,canvas.width,canvas.height);
      ctx.drawImage(img,(frame%cols)*cell,Math.floor(frame/cols)*cell,cell,cell,0,0,canvas.width,canvas.height);
    }
    function frames(img,total,duration){
      return new Promise(resolve=>{
        let start=null,last=-1;
        const tick=now=>{
          if(start===null)start=now;
          const t=Math.min(1,(now-start)/duration);
          const f=Math.min(total-1,Math.floor(t*total));
          if(f!==last){draw(img,f);last=f;}
          if(t>=1)resolve();else requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
      });
    }
    async function animateRoll(result){
      if(!canvas)return;
      $('dice-stage-placeholder').hidden=true;
      canvas.style.display='block';
      try{
        const settle=await getImage(settleURL(result));
        if(window.matchMedia('(prefers-reduced-motion: reduce)').matches){draw(settle,23);return;}
        const spin=await getImage(spinURL);
        await frames(spin,30,920);
        await frames(settle,24,740);
      }catch(e){
        canvas.style.display='none';$('dice-stage-placeholder').hidden=false;text('dice-stage-placeholder',`D20 · ${result}`);
      }
    }
    form.addEventListener('submit',async event=>{
      event.preventDefault();if(busy||!form.reportValidity())return;
      busy=true;rollButton.disabled=true;rollButton.textContent='ROLLING…';
      const sides=Number($('dice-type').value);
      const count=clamp(Math.trunc(Number($('dice-count').value)),1,20);
      const modifier=clamp(Math.trunc(Number($('dice-modifier').value)),-100,100);
      const special=sides===20&&count===1?mode.value:'normal';
      const faces=Array.from({length:special==='normal'?count:2},()=>1+rand(sides));
      const effective=special==='advantage'?Math.max(...faces):special==='disadvantage'?Math.min(...faces):null;
      const total=(effective===null?faces.reduce((a,b)=>a+b,0):effective)+modifier;
      const primary=effective===null?faces[0]:effective;lastFace=primary;
      const expression=`${count}d${sides}${modifier?` ${modifier<0?'−':'+'} ${Math.abs(modifier)}`:''}${special!=='normal'?` · ${special}`:''}`;
      text('dice-expression','The die is spinning…');
      if(sides===20){await animateRoll(primary);}else{canvas.style.display='none';$('dice-stage-placeholder').hidden=false;text('dice-stage-placeholder',`D${sides}`);await new Promise(r=>setTimeout(r,160));}
      text('dice-total',total);text('dice-expression',expression);
      $('dice-faces').replaceChildren();faces.forEach(n=>{const el=document.createElement('span');el.textContent=n;$('dice-faces').append(el);});
      history.unshift(`${expression}: ${faces.join(', ')} → ${total}`);history.splice(12);
      historyList.replaceChildren();history.forEach(s=>{const li=document.createElement('li');li.textContent=s;historyList.append(li);});
      $('dice-total').animate?.([{transform:'scale(.75)',opacity:.5},{transform:'scale(1)',opacity:1}],{duration:280});
      busy=false;rollButton.disabled=false;rollButton.textContent='ROLL DICE';
    });
    $('dice-clear').addEventListener('click',()=>{history.length=0;historyList.replaceChildren();text('dice-expression','History cleared');});
    // Preview the D20 before first roll; no simulated result is shown.
    getImage(settleURL(lastFace)).then(img=>{if(!busy)draw(img,23);}).catch(()=>{});
  }

  function initBattle() {
    const {heroes,enemies}=database.characters;
    const heroSel=$('battle-hero'),stageSel=$('battle-stage'),enemySel=$('battle-enemy');
    let player=null,enemy=null,busy=false,round=0;
    const entry=msg=>{const el=document.createElement('li');el.textContent=msg;$('battle-log').prepend(el);while($('battle-log').children.length>16)$('battle-log').lastChild.remove();};
    const update=()=>{
      for(const [name,data] of [['player',player],['enemy',enemy]]){
        text(`battle-${name}-name`,data.name);
        text(`battle-${name}-hp`,`${data.hp} / ${data.maxHp} HP`);
        $(`battle-${name}-bar`).style.width=`${Math.round(100*data.hp/data.maxHp)}%`;
      }
    };
    const pulse=side=>{const el=$(side==='player'?'battle-player':'battle-opponent');el.classList.remove('hit');void el.offsetWidth;el.classList.add('hit');};
    function start(){
      const h=heroSel.value, m=enemies.find(x=>x.id===enemySel.value), stage=+stageSel.value;
      if(!heroes[h]||!m)return;
      player={name:h[0].toUpperCase()+h.slice(1),hp:35+stage*9,maxHp:35+stage*9,atk:4+stage*2,def:12+stage,stage};
      enemy={name:m.name,hp:38+rand(19),maxHp:0,atk:6,def:13};enemy.maxHp=enemy.hp;
      setResultArt('battle-player-image',heroes[h][stage-1]);
      setResultArt('battle-enemy-image',m.art);
      $('battle-player-image').setAttribute('aria-label',`${player.name} Stage ${stage}`);
      $('battle-enemy-image').setAttribute('aria-label',enemy.name);
      $('battle-log').replaceChildren();round=0;
      $('battle-attack').disabled=false;
      text('battle-status','Ready to fight! Roll the D20.');
      entry('Illustrative simulator rules, not official KardRune battle stats.');
      update();
    }
    function strike(from,to){
      const die=rand(20)+1;
      const hits=die===20||(die!==1&&die+from.atk>=to.def);
      const damage=hits?(die===20?2:1)*Math.max(1,3+Math.floor(die/4)+Math.floor(from.atk/2)):0;
      to.hp=Math.max(0,to.hp-damage);
      entry(`${from.name} rolls ${die} + ${from.atk}: ${!hits?'MISS':die===20?`CRITICAL · ${damage} damage`:`${damage} damage`}.`);
      if(hits)pulse(to===player?'player':'enemy');
    }
    $('battle-start').addEventListener('click',()=>{if(!busy)start();});
    $('battle-attack').addEventListener('click',async()=>{
      if(busy||!player||!enemy||player.hp<=0||enemy.hp<=0)return;
      busy=true;$('battle-attack').disabled=true;round++;
      strike(player,enemy);update();
      if(enemy.hp>0){await new Promise(r=>setTimeout(r,430));strike(enemy,player);update();}
      const result=enemy.hp<=0?'Victory! The monster is defeated.':player.hp<=0?'Defeat! Challenge again.':`Round ${round} complete. Roll again.`;
      text('battle-status',result);
      if(enemy.hp<=0||player.hp<=0)entry(result);else $('battle-attack').disabled=false;
      busy=false;
    });
    start();
  }

  function initLibrary(){
    const gallery=$('art-gallery');if(!gallery)return;
    const all=Object.entries(database.assets.entries);
    const pretty=id=>id.split('/').pop().replace(/\.[^.]+$/,'').replace(/[_-]/g,' ').replace(/\b\w/g,m=>m.toUpperCase());
    const group=id=>id.split('/')[0];
    let pageSize=48,matched=[];
    const render=()=>{
      const q=$('art-query').value.trim().toLowerCase(),cat=$('art-group').value;
      matched=all.filter(([id,entry])=>(cat==='all'||(cat==='other'?!['cards','journey','conquest','battle','backgrounds','summon','home','ui'].includes(group(id)):group(id)===cat))&&(!q||id.toLowerCase().includes(q)));
      gallery.replaceChildren();
      for(const [id,entry] of matched.slice(0,pageSize)){
        const node=document.createElement('article');node.className='art-item';
        const art=document.createElement('div');art.className='art-thumb game-art';art.setAttribute('role','img');art.setAttribute('aria-label',pretty(id));applyArt(art,id);
        const caption=document.createElement('div');
        const name=document.createElement('strong');name.textContent=pretty(id);
        const sub=document.createElement('span');sub.textContent=id.split('/').slice(0,-1).join(' / ');
        caption.append(name,sub);node.append(art,caption);gallery.append(node);
      }
      text('art-count',`${matched.length} image${matched.length===1?'':'s'} found · ${Math.min(matched.length,pageSize)} shown`);
      $('art-more').hidden=pageSize>=matched.length;
    };
    ['art-query','art-group'].forEach(id=>$(id).addEventListener('input',()=>{pageSize=48;render();}));
    $('art-more').addEventListener('click',()=>{pageSize+=48;render();});render();
  }

  function initCardPresets(){
    const select=$('card-preset'),stage=$('card-preset-stage');if(!select||!stage)return;
    const update=async()=>{
      const key=select.value,art=database.characters.heroes[key]?.[Number(stage.value)-1];
      if(!art)return;
      const label=$('card-message');label.textContent='Loading KardRune hero artwork…';
      try{
        const image=await assetCanvasImage(art);
        // Existing card editor handles the resulting image through its standard upload-compatible pathway.
        document.dispatchEvent(new CustomEvent('kardrune-card-preset',{detail:{src:image,name:key[0].toUpperCase()+key.slice(1),stage:Number(stage.value)}}));
        label.textContent=`Using ${key.toUpperCase()} Stage ${stage.value} from the game art library.`;
      }catch{label.textContent='Unable to load this portrait. Try another hero.';}
    };
    select.addEventListener('change',update);stage.addEventListener('change',update);
    $('card-reset').addEventListener('click',()=>{select.value='';stage.value='1';});
  }

  function initGachaReveal(){
    const btn=$('gacha-simulate');if(!btn)return;
    btn.addEventListener('click',()=>{
      const name=heroNames[rand(heroNames.length)];
      const stage=rand(3)+1;
      const art=database.characters.heroes[name.toLowerCase()]?.[stage-1];if(!art)return;
      setResultArt('summon-reveal-art',art);
      text('summon-reveal-name',`${name.toUpperCase()} · STAGE ${stage}`);
      text('summon-reveal-tag','Art preview only — not an in-game reward');
    });
  }

  function initLootArt(){
    const list=$('loot-results');if(!list)return;
    const assets=['ui/gold_coin.webp','ui/hero_chest_key.webp','summon/ui/gold_ticket.webp','rune_altar/shard_rune.webp','battle/items/max_dice.webp','battle/items/double_dice.webp'];
    const observer=new MutationObserver(()=>{
      Array.from(list.children).forEach((li,i)=>{
        if(li.querySelector('.loot-icon'))return;
        const art=document.createElement('span');art.className='loot-icon game-art';applyArt(art,assets[i%assets.length]);li.prepend(art);
      });
    });
    observer.observe(list,{childList:true,subtree:false});
    Array.from(list.children).forEach((li,i)=>{const art=document.createElement('span');art.className='loot-icon game-art';applyArt(art,assets[i%assets.length]);li.prepend(art);});
  }

  assetReady.then(data=>{
    database=data;
    refreshArtwork();
    if(page==='wiki')initWiki();
    if(page==='dice')initDice();
    if(page==='battle')initBattle();
    if(page==='card')initCardPresets();
    if(page==='gacha')initGachaReveal();
    if(page==='loot')initLootArt();
    if(page==='art-library')initLibrary();
  }).catch(e=>{
    console.warn('KardRune optimized art library could not load',e);
    if(page==='art-library')text('art-count','Artwork cannot be loaded right now. Reload the page.');
    if(page==='dice')text('dice-expression','Dice artwork unavailable; try refreshing.');
  });
})();
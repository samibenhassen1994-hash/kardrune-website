import * as T from './vendor/three.module.js';

import {GLTFLoader} from './vendor/GLTFLoader.js';

import {Duel} from './duel-state.mjs';

const $=id=>document.getElementById(id);

export async function mount(){

 const canvas=document.querySelector('canvas'),stage=document.querySelector('.arena');
 const roster={ares:['Ares','Ares.glb',3.7],atena:['Atena','Athena.glb',3.4],ade:['Ade','Hades.glb',3.8],zeus:['Zeus','ZeusCombat.glb',4.15],sam:['Sam','SamCombat.glb',2.8]};
 const params=new URLSearchParams(location.search);
 if(params.get('embedded')==='1'){document.querySelector('header').hidden=true;$('back-game').hidden=true;}
 const pick=(key,fallback)=>Object.hasOwn(roster,params.get(key))?params.get(key):fallback;
 const ids={hero:pick('hero','atena'),zeus:pick('opponent','zeus')};
 const game=new Duel(ids);
 const label=id=>roster[ids[id]][0];
 for(const [select,slot,key] of [['left','hero','hero'],['right','zeus','opponent']]){
  $(select).replaceChildren(...Object.entries(roster).map(([id,[name]])=>new Option(name,id)));
  $(select).value=ids[slot];$(select).onchange=()=>{params.set(key,$(select).value);location.search=params;};
  $(slot+'-card').querySelector('h2').textContent=label(slot);
 }
 const spells=[
  ['Cast2','Dardo solare',0xffb645],['Cast3','Luce dello zaffiro',0x64ddff],
  ['Cast4','Sigillo di Atena',0xffda70],['Cast5','Giudizio dellâ€™aurora',0xff866f],
  ['Cast6','Fiamma sacra',0xff9237],['Cast7','Impulso celeste',0xad9cff],
  ['Cast8','Lampo dorato',0xffeb98]
 ];
 const choices={ares:[['Attack','Attacco normale'],['WarFury','Furia di Guerra'],['Crouch_and_Step_Back','Passo evasivo'],['Jump_with_Arms_and_Legs_Open','Assalto in salto']],atena:spells,ade:[['Attack','Attacco normale'],['ShadowPact','Patto delle Ombre']],zeus:[['Attack','Colpo fisico'],['DivineJudgment','Giudizio Divino']],sam:[['Attack','Colpo fisico'],['C1','Colpo preciso'],['C2','Pelle dura'],['C3','Resistenza'],['C4','Tenacia'],['C5','Mira stabile']]};
 const selected=Object.fromEntries(Object.keys(ids).map(slot=>[slot,choices[ids[slot]][0][0]]));
 let displayedTurn;
 const hintFor=id=>ids[id]==='ares'?'Furia di Guerra: +12% ATK e +15 danni al primo attacco.':ids[id]==='ade'?'Patto delle Ombre recupera il 12% del danno diretto inflitto.':'Scegli unâ€™abilitÃ  sotto Attacco, oppure para.';
 const scene=new T.Scene();scene.fog=new T.FogExp2(0x121e30,.025);

 const camera=new T.PerspectiveCamera(34,1,.1,80);let focused=false;

 const renderer=new T.WebGLRenderer({canvas,alpha:true,antialias:true,powerPreference:'high-performance'});renderer.outputColorSpace=T.SRGBColorSpace;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;

 scene.add(new T.HemisphereLight(0xcedfff,0x44405c,2));

 for(const [pos,color,power] of [[[0,7,5],0xffe6c6,3],[[-5,4,1],0x95baff,2],[[3,5,-4],0x4fa5ff,4]]){const l=new T.DirectionalLight(color,power);l.position.set(...pos);scene.add(l);}

 const flash=new T.PointLight(0x74ceff,0,14);flash.position.set(1,3,1);scene.add(flash);

 const fighters={};let preview=0;let active=null,disposed=false,raf=0,last=0,fxTime=0,bolts=new T.Group();scene.add(bolts);

 const abort=new AbortController();

 function free(root){const gs=new Set(),ms=new Set(),ts=new Set();root.traverse(o=>{if(o.geometry)gs.add(o.geometry);for(const m of [].concat(o.material||[])){ms.add(m);for(const v of Object.values(m))if(v?.isTexture)ts.add(v);}});gs.forEach(g=>g.dispose());ms.forEach(m=>m.dispose());ts.forEach(t=>{t.dispose();t.source?.data?.close?.();});}

 function clearBolts(){for(const o of [...bolts.children]){free(o);bolts.remove(o);}flash.intensity=0;document.body.dataset.lightning='false';}

 function resize(){const w=stage.clientWidth,h=stage.clientHeight;renderer.setPixelRatio(Math.min(devicePixelRatio,1.5,Math.sqrt(1400000/(w*h))));renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();frameCamera();}

 function frameCamera(){if(fighters.hero)fighters.hero.model.visible=!focused;if(focused){camera.position.set(3.7,3.7,6.0);camera.lookAt(1.35,2.95,0);}else{const mobile=camera.aspect<1;camera.position.set(0,mobile?7.4:6.5,mobile?16.4:12.5);camera.lookAt(0,1.85,0);}camera.updateProjectionMatrix();}

 const observer=new ResizeObserver(resize);observer.observe(stage);

 function clipSpeed(id,name){
  return ids[id]==='ares' && ['Attack','WarFury','Crouch_and_Step_Back','Jump_with_Arms_and_Legs_Open','Parry'].includes(name)?1.7:1;
 }
 function clipDuration(id,name){
  return fighters[id].actions[name].getClip().duration/clipSpeed(id,name);
 }
 function play(id,name){const f=fighters[id];if(!f)return;if(name==='Idle'&&(id!==game.turn||!f.actions.Idle))name='Waiting';

  const next=f.actions[name],loop=name==='Idle'||name==='Waiting';f.mixer.stopAllAction();next.reset().setEffectiveTimeScale(clipSpeed(id,name)).setLoop(loop?T.LoopRepeat:T.LoopOnce,loop?Infinity:1);next.clampWhenFinished=!loop;next.play();f.current=name;document.body.dataset[id+'Clip']=name;}

 function ui(){const busy=preview>0||!!active||!fighters.zeus||!fighters.hero;const end=!!game.winner;

  for(const id of ['hero','zeus']){$(id+'-hp').textContent=`${game.hp[id]} / ${game.maximum(id)}`;$(id+'-bar').style.width=(100*game.hp[id]/(game.maximum(id)))+'%';$(id+'-card').classList.toggle('active',game.turn===id&&!end);}

  $('attack').disabled=busy||end;$('guard').disabled=busy||end;$('judgment').disabled=busy||end||game.turn!=='zeus';

  const turn=game.turn;
  if(displayedTurn!==turn){
   $('skill').replaceChildren(...choices[ids[turn]].map(([id,name])=>new Option(name,id)));
   $('skill').value=selected[turn];displayedTurn=turn;
  }
  $('turn').textContent=end?'DUELLO CONCLUSO':busy?'AZIONE IN CORSO':label(turn);
  $('round').textContent='TURNO '+game.round;
  $('action-title').textContent=end?'Vince '+label(game.winner):busy?'Azione in corsoâ€¦':'Turno di '+label(turn);
  $('hint').textContent=hintFor(turn);$('info').textContent=Object.values(ids).includes('ade')?hintFor(Object.keys(ids).find(id=>ids[id]==='ade')):'';
  $('previewSkill').disabled=busy||end;$('skill').disabled=busy||end;
  $('attack').querySelector('small').textContent=skillName(selected[turn]);
  document.body.dataset.turn=game.turn;document.body.dataset.busy=String(!!active);document.body.dataset.winner=game.winner||'';

 }

 function log(text){const li=document.createElement('li');li.textContent=text;$('log').prepend(li);while($('log').children.length>6)$('log').lastChild.remove();}

 function start(kind){if(active||disposed)return;if(focused){focused=false;frameCamera();$('focus').textContent='OSSERVA '+label('zeus');}const a=game.begin(kind);if(!a)return;

  const clip=kind==='guard'?'Parry':selected[a.actor];
  const length=clipDuration(a.actor,clip);

  const impact=kind==='judgment'?1.28:length*.45;

  active={...a,clip,time:0,impact,duration:kind==='guard'?length:Math.max(length,impact+clipDuration(a.target,'Hit')),done:false};

  play(a.actor,clip);play(a.target,'Waiting');

  $('announcement').textContent=kind==='judgment'?'GIUDIZIO DIVINO':kind==='guard'?'GUARDIA ALZATA':skillName(clip);document.body.dataset.action=kind;ui();

 }

 function lightning(){clearBolts();const target=fighters[active.target].model.position;const start=new T.Vector3(1.05,3.35,.12);const end=new T.Vector3(target.x,1.55,.12);

  for(let branch=0;branch<4;branch++){fighters[active.actor].hands[branch%2].getWorldPosition(start);const pts=[];for(let i=0;i<15;i++){const t=i/14;const p=start.clone().lerp(end,t);if(i&&i<14){p.x+=(Math.random()-.5)*.3;p.y+=(Math.random()-.5)*.55;p.z+=(Math.random()-.5)*.32;}pts.push(p);}

   const c=new T.CatmullRomCurve3(pts,false,'catmullrom',.02);for(const [r,color,opacity] of [[.014,0xeaffff,1],[.045,0x1d8fff,.23]]){const m=new T.Mesh(new T.TubeGeometry(c,30,r,4,false),new T.MeshBasicMaterial({color,transparent:opacity<1,opacity,depthWrite:false,blending:T.AdditiveBlending}));bolts.add(m);}

  }

  // Descending bolt makes the divine cast legible even on narrow viewports.

  const points=[new T.Vector3(target.x+.5,7,0),new T.Vector3(target.x-.25,5.2,.1),new T.Vector3(target.x+.2,4.5,0),new T.Vector3(target.x-.15,3.2,.1),end];

  bolts.add(new T.Line(new T.BufferGeometry().setFromPoints(points),new T.LineBasicMaterial({color:0xc5f8ff})));flash.intensity=8;document.body.dataset.lightning='true';

 }

 const flare=new T.Group();
 const spark=new T.Mesh(new T.IcosahedronGeometry(.16,1),new T.MeshBasicMaterial({blending:T.AdditiveBlending,transparent:true,depthWrite:false}));
 const halo=new T.Mesh(new T.TorusGeometry(.35,.035,8,36),spark.material.clone());
 flare.add(spark,halo);scene.add(flare);flare.visible=false;
 function spellEffect(id,time,impact,slot){
  if((id==='ShadowPact'||id==='WarFury') && Math.abs(time-impact)<.65){
   const phase=(time-impact+.65)/1.3;
   flare.visible=true;flare.position.set(fighters[slot].model.position.x,.09,0);
   spark.scale.setScalar(.01);halo.rotation.set(-Math.PI/2,0,0);halo.scale.setScalar(.4+phase*8);
   halo.material.color.setHex(id==='WarFury'?0xff5225:0xc15dff);halo.material.opacity=Math.sin(Math.PI*phase);return;
  }
  const spell=spells.find(([key])=>key===id);
  if(!spell || time>impact+.42)return;
  const hero=fighters[slot],hand=hero.hands[0];if(!hand)return;
  const from=hand.getWorldPosition(new T.Vector3()),to=new T.Vector3(fighters[slot==="hero"?"zeus":"hero"].baseX,2.15,.25);
  const travel=Math.min(.42,impact*.55),t=T.MathUtils.clamp((time-impact+travel)/travel,0,1);
  const burst=Math.max(0,(time-impact)/.42);
  flare.visible=true;flare.position.copy(from).lerp(to,t);flare.position.y+=.45*Math.sin(Math.PI*t);
  spark.material.color.setHex(spell[2]);halo.material.color.setHex(spell[2]);
  spark.scale.setScalar((.65+.35*Math.sin(time*12)**2)*(1-burst));halo.scale.setScalar(.7+burst*3);
  halo.quaternion.copy(camera.quaternion);halo.rotateZ(time*5);halo.material.opacity=1-burst;
 }
 function reset(){flare.visible=false;preview=0;game.reset();active=null;clearBolts();for(const id of ['hero','zeus']){if(fighters[id]){fighters[id].model.rotation.z=0;fighters[id].model.position.x=fighters[id].baseX;fighters[id].model.rotation.y=fighters[id].baseYaw;play(id,'Idle');}}$('announcement').textContent='';$('damage').textContent='';$('log').replaceChildren();log(label('hero')+' apre lo scontro.');document.body.dataset.action='';ui();}

 function tick(now){if(disposed||document.hidden)return;const dt=last?Math.min((now-last)/1000,.05):0;last=now;

  for(const f of Object.values(fighters))f.mixer.update(dt);

  flare.visible=false;
  if(preview>0){const f=fighters[game.turn];const len=clipDuration(game.turn,f.current);spellEffect(f.current,len-preview,len*.45,game.turn);}
  if(preview>0){preview=Math.max(0,preview-dt);if(!preview){play(game.turn,'Idle');$('announcement').textContent='';ui();}}

  if(active){active.time+=dt;const a=active; spellEffect(a.clip,a.time,a.impact,a.actor);

   const actor=fighters[a.actor];const wave=Math.sin(Math.PI*Math.min(1,a.time/a.duration))**2;

   if(a.kind==='attack'){actor.model.position.x=actor.baseX+(a.actor==='hero'?1.15:-.85)*wave;}



   if(a.kind==='judgment'&&a.time>1.17&&a.time<1.60){fxTime+=dt;if(fxTime>.07){lightning();fxTime=0;}}else clearBolts();

   if(!a.done&&a.time>=a.impact){a.done=true;const result=game.resolve(a.id);if(result){

    if(a.healed)log(label(a.actor)+' recupera '+a.healed+' PS');

    if(a.kind!=='guard'){

     play(a.target,'Hit');const p=new T.Vector3(fighters[a.target].model.position.x,2.4,.3).project(camera);$('damage').style.left=(p.x*.5+.5)*stage.clientWidth+'px';$('damage').style.top=(-p.y*.5+.5)*stage.clientHeight+'px';$('damage').textContent='âˆ’'+a.damage;

     log(`${label(a.actor)} Â· ${choices[ids[a.actor]].find(([clip])=>clip===a.clip)?.[1] || 'attacco'}: ${a.damage} danni.`);

    }else log((label(a.actor))+' in guardia: prossimo danno dimezzato.');ui();

   }}

   if(a.time>=a.duration){active=null;clearBolts();$('damage').textContent='';$('announcement').textContent=game.winner?('VITTORIA DI '+label(game.winner)):'';for(const id of ['hero','zeus']){fighters[id].model.position.x=fighters[id].baseX;fighters[id].model.rotation.y=fighters[id].baseYaw;play(id,game.winner?(id===game.winner?'Victory':'Defeat'):'Idle');}ui();}

  }

  renderer.render(scene,camera);raf=requestAnimationFrame(tick);

 }

 function visibility(){cancelAnimationFrame(raf);last=0;if(!document.hidden&&!disposed)raf=requestAnimationFrame(tick);}

 function dispose(){if(disposed)return;disposed=true;abort.abort();cancelAnimationFrame(raf);observer.disconnect();document.removeEventListener('visibilitychange',visibility);window.removeEventListener('pagehide',pageHide);window.removeEventListener('pageshow',pageShow);for(const f of Object.values(fighters)){f.mixer.stopAllAction();f.mixer.uncacheRoot(f.model);}free(scene);renderer.dispose();renderer.forceContextLoss();}

 function pageHide(e){if(e.persisted){cancelAnimationFrame(raf);last=0;}else dispose();}

 function pageShow(e){if(e.persisted)visibility();}

 window.addEventListener('pagehide',pageHide);window.addEventListener('pageshow',pageShow);document.addEventListener('visibilitychange',visibility);

 canvas.addEventListener('webglcontextlost',e=>{if(disposed)return;e.preventDefault();$('loading').hidden=false;$('loading').textContent='Contesto grafico perso. Ricarica la pagina.';for(const id of ['attack','guard','judgment'])$(id).disabled=true;dispose();});

 function skillName(id){return Array.from($('skill').options).find(o=>o.value===id)?.textContent||'';}

 function showSkill(id){if(!id||active||preview)return;if(focused)$('focus').click();play(game.turn,id);preview=clipDuration(game.turn,id);$('announcement').textContent=skillName(id);ui();}

 $('skill').onchange=()=>{const id=game.turn,oldMax=game.maximum(id);selected[id]=$('skill').value;game.skills[id]=selected[id];game.hp[id]=Math.max(1,game.hp[id]+game.maximum(id)-oldMax);ui();};
 $('previewSkill').onclick=()=>showSkill(selected[game.turn]);
 $('attack').onclick=()=>start(selected[game.turn]==='DivineJudgment'?'judgment':'attack');$('guard').onclick=()=>start('guard');$('judgment').onclick=()=>start('judgment');$('reset').onclick=reset;$('focus').onclick=()=>{focused=!focused;frameCamera();$('focus').textContent=focused?'TORNA ALLâ€™ARENA':'OSSERVA '+label('zeus');};

 try{

  const arena=await new GLTFLoader().loadAsync('RoyalArena.glb');scene.add(arena.scene);
  $('focus').textContent='OSSERVA '+label('zeus');
  for(const [id,x,rotation] of [['hero',-1.55,Math.PI/2],['zeus',1.4,-Math.PI/2]]){
   const [,url,height]=roster[ids[id]];
   const response=await fetch(url,{signal:abort.signal});if(!response.ok)throw Error(`Asset ${id}: HTTP ${response.status}`);

   const gltf=await new GLTFLoader().parseAsync(await response.arrayBuffer(),location.href);if(disposed){free(gltf.scene);return;}

   const model=gltf.scene;
   // Scale the body independently of the removable sword.
   const body=model.getObjectByName('Mesh_0') || model;
   const box=new T.Box3().setFromObject(body);model.scale.setScalar(height/(box.max.y-box.min.y));model.position.set(x,-box.min.y*model.scale.x,0);model.rotation.y=rotation;scene.add(model);

   const mixer=new T.AnimationMixer(model),actions={};for(const c of gltf.animations)actions[c.name]=mixer.clipAction(c);

   for(const name of ['Waiting','Parry','Hit','Victory','Defeat',...choices[ids[id]].map(([clip])=>clip)])if(!actions[name])throw Error(`Clip ${name} mancante per ${id}`);

   const hands=[];model.traverse(o=>{if(o.isBone&&/(Left|Right)Hand$/i.test(o.name))hands.push(o);});if(ids[id]==='zeus'&&hands.length!==2)throw Error('Mani Mixamo mancanti');fighters[id]={model,mixer,actions,hands,baseX:x,baseYaw:rotation};play(id,'Idle');

  }

  $('loading').hidden=true;document.body.dataset.ready='true';ui();resize();raf=requestAnimationFrame(tick);

 }catch(e){if(disposed)return;$('loading').hidden=false;$('loading').textContent='Impossibile caricare i personaggi. Ricarica la pagina.';console.error(e);dispose();}

}


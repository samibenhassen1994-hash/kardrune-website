import * as T from './vendor/three.module.js';
import {GLTFLoader} from './vendor/GLTFLoader.js';
import {Duel} from './duel-state.mjs';
const $=id=>document.getElementById(id);
export async function mount(){
 const game=new Duel(),canvas=document.querySelector('canvas'),stage=document.querySelector('.arena');
 const athena=new URLSearchParams(location.search).get('hero')==='atena';
 const heroName=athena?'Atena':'Sam';
 if(athena){
  game.reset('D4');$('skill').replaceChildren(new Option('Egida della Saggezza','D4',true,true));
  $('skillLabel').textContent='Abilit� di Atena';$('hero-card').querySelector('h2').textContent='Atena';
  $('challenger').textContent='Gioca con Sam';$('challenger').href='?hero=sam';
  $('equipSkill').textContent='Ricomincia con Egida';
 }
 const scene=new T.Scene();scene.fog=new T.FogExp2(0x121e30,.025);
 const camera=new T.PerspectiveCamera(34,1,.1,80);let focused=false;
 const renderer=new T.WebGLRenderer({canvas,alpha:true,antialias:true,powerPreference:'high-performance'});renderer.outputColorSpace=T.SRGBColorSpace;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;
 scene.add(new T.HemisphereLight(0xcedfff,0x44405c,2));
 for(const [pos,color,power] of [[[0,7,5],0xffe6c6,3],[[-5,4,1],0x95baff,2],[[3,5,-4],0x4fa5ff,4]]){const l=new T.DirectionalLight(color,power);l.position.set(...pos);scene.add(l);}
 const flash=new T.PointLight(0x74ceff,0,14);flash.position.set(1,3,1);scene.add(flash);
 const floor=new T.Mesh(new T.CylinderGeometry(5,5.15,.16,96),new T.MeshStandardMaterial({color:0x253449,metalness:.3,roughness:.55}));floor.position.y=-.10;scene.add(floor);
 for(const radius of [4.6,4.8]){const ring=new T.Mesh(new T.TorusGeometry(radius,.013,5,96),new T.MeshBasicMaterial({color:0x728694}));ring.rotation.x=Math.PI/2;ring.position.y=.001;scene.add(ring);}
 for(let i=0;i<16;i++){const a=i*Math.PI/8;const rune=new T.Mesh(new T.BoxGeometry(.035,.014,.24),new T.MeshBasicMaterial({color:0x678599}));rune.position.set(Math.sin(a)*4.3,0,Math.cos(a)*4.3);rune.rotation.y=a;scene.add(rune);}
 const fighters={};let preview=0;let active=null,disposed=false,raf=0,last=0,fxTime=0,bolts=new T.Group();scene.add(bolts);
 const abort=new AbortController();
 function free(root){const gs=new Set(),ms=new Set(),ts=new Set();root.traverse(o=>{if(o.geometry)gs.add(o.geometry);for(const m of [].concat(o.material||[])){ms.add(m);for(const v of Object.values(m))if(v?.isTexture)ts.add(v);}});gs.forEach(g=>g.dispose());ms.forEach(m=>m.dispose());ts.forEach(t=>{t.dispose();t.source?.data?.close?.();});}
 function clearBolts(){for(const o of [...bolts.children]){free(o);bolts.remove(o);}flash.intensity=0;document.body.dataset.lightning='false';}
 function resize(){const w=stage.clientWidth,h=stage.clientHeight;renderer.setPixelRatio(Math.min(devicePixelRatio,1.5,Math.sqrt(1400000/(w*h))));renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();frameCamera();}
 function frameCamera(){if(fighters.hero)fighters.hero.model.visible=!focused;if(focused){camera.position.set(3.7,3.7,6.0);camera.lookAt(1.35,2.95,0);}else{const mobile=camera.aspect<1;camera.position.set(0,mobile?5.1:4.1,mobile?15.7:11.6);camera.lookAt(0,1.85,0);}camera.updateProjectionMatrix();}
 const observer=new ResizeObserver(resize);observer.observe(stage);
 function play(id,name){const f=fighters[id];if(!f)return;if(name==='Idle'&&(id!==game.turn||!f.actions.Idle))name='Waiting';
  const next=f.actions[name],loop=name==='Idle'||name==='Waiting';f.mixer.stopAllAction();next.reset().setLoop(loop?T.LoopRepeat:T.LoopOnce,loop?Infinity:1);next.clampWhenFinished=!loop;next.play();f.current=name;document.body.dataset[id+'Clip']=name;}
 function ui(){const busy=preview>0||!!active||!fighters.zeus||!fighters.hero;const end=!!game.winner;
  for(const id of ['hero','zeus']){$(id+'-hp').textContent=`${game.hp[id]} / ${id==='hero'?(game.skill==='C3'?255:240):260}`;$(id+'-bar').style.width=(100*game.hp[id]/(id==='hero'?(game.skill==='C3'?255:240):260))+'%';$(id+'-card').classList.toggle('active',game.turn===id&&!end);}
  $('attack').disabled=busy||end;$('guard').disabled=busy||end;$('judgment').disabled=busy||end||game.turn!=='zeus';
  $('turn').textContent=end?'DUELLO CONCLUSO':busy?'AZIONE IN CORSO':game.turn==='hero'?heroName.toUpperCase():'ZEUS';$('round').textContent='TURNO '+game.round;
  $('action-title').textContent=end?(game.winner==='hero'?'Vince l’avventuriero':'Zeus trionfa'):busy?'Azione in corso…':game.turn==='hero'?'Turno dell’avventuriero':'Turno di Zeus';
  $('hint').textContent=end?'Ricomincia per provare una strategia diversa.':game.turn==='zeus'?'Attiva Giudizio Divino per scatenare la tempesta.':'Attacca oppure para il prossimo colpo di Zeus.';
  $('previewSkill').disabled=busy||!$('skill').value;$('equipSkill').disabled=busy;$('skill').disabled=busy;
  document.body.dataset.turn=game.turn;document.body.dataset.busy=String(!!active);document.body.dataset.winner=game.winner||'';
 }
 function log(text){const li=document.createElement('li');li.textContent=text;$('log').prepend(li);while($('log').children.length>6)$('log').lastChild.remove();}
 function start(kind){if(active||disposed)return;if(focused){focused=false;frameCamera();$('focus').textContent='OSSERVA ZEUS';}const a=game.begin(kind);if(!a)return;
  const clip=a.triggered&&a.actor==='hero'?game.skill:kind==='judgment'?'DivineJudgment':kind==='guard'?'Parry':'Attack';
  const length=fighters[a.actor].actions[clip].getClip().duration;
  const impact=kind==='judgment'?1.28:length*.45;
  active={...a,time:0,impact,duration:kind==='guard'?length:Math.max(length,impact+fighters[a.target].actions.Hit.getClip().duration),done:false};
  play(a.actor,clip);play(a.target,'Waiting');
  $('announcement').textContent=kind==='judgment'?'GIUDIZIO DIVINO':kind==='guard'?'GUARDIA ALZATA':'';document.body.dataset.action=kind;ui();
 }
 function lightning(){clearBolts();const target=fighters[active.target].model.position;const start=new T.Vector3(1.05,3.35,.12);const end=new T.Vector3(target.x,1.55,.12);
  for(let branch=0;branch<4;branch++){fighters.zeus.hands[branch%2].getWorldPosition(start);const pts=[];for(let i=0;i<15;i++){const t=i/14;const p=start.clone().lerp(end,t);if(i&&i<14){p.x+=(Math.random()-.5)*.3;p.y+=(Math.random()-.5)*.55;p.z+=(Math.random()-.5)*.32;}pts.push(p);}
   const c=new T.CatmullRomCurve3(pts,false,'catmullrom',.02);for(const [r,color,opacity] of [[.014,0xeaffff,1],[.045,0x1d8fff,.23]]){const m=new T.Mesh(new T.TubeGeometry(c,30,r,4,false),new T.MeshBasicMaterial({color,transparent:opacity<1,opacity,depthWrite:false,blending:T.AdditiveBlending}));bolts.add(m);}
  }
  // Descending bolt makes the divine cast legible even on narrow viewports.
  const points=[new T.Vector3(target.x+.5,7,0),new T.Vector3(target.x-.25,5.2,.1),new T.Vector3(target.x+.2,4.5,0),new T.Vector3(target.x-.15,3.2,.1),end];
  bolts.add(new T.Line(new T.BufferGeometry().setFromPoints(points),new T.LineBasicMaterial({color:0xc5f8ff})));flash.intensity=8;document.body.dataset.lightning='true';
 }
 function reset(){preview=0;game.reset();active=null;clearBolts();for(const id of ['hero','zeus']){if(fighters[id]){fighters[id].model.rotation.z=0;fighters[id].model.position.x=fighters[id].baseX;fighters[id].model.rotation.y=fighters[id].baseYaw;play(id,'Idle');}}$('announcement').textContent='';$('damage').textContent='';$('log').replaceChildren();log('Nouveau duel : l’avventuriero apre lo scontro.'.replace('Nouveau duel','Nuovo duello'));document.body.dataset.action='';ui();}
 function tick(now){if(disposed||document.hidden)return;const dt=last?Math.min((now-last)/1000,.05):0;last=now;
  for(const f of Object.values(fighters))f.mixer.update(dt);
  if(preview>0){preview=Math.max(0,preview-dt);if(!preview){play('hero','Idle');$('announcement').textContent='';ui();}}
  if(active){active.time+=dt;const a=active;
   const actor=fighters[a.actor];const wave=Math.sin(Math.PI*Math.min(1,a.time/a.duration))**2;
   if(a.kind==='attack'){actor.model.position.x=actor.baseX+(a.actor==='hero'?1.15:-.85)*wave;actor.model.rotation.y=actor.baseYaw+((a.actor==='hero'?1.2:-1.2)-actor.baseYaw)*wave;}

   if(a.kind==='judgment'&&a.time>1.17&&a.time<1.60){fxTime+=dt;if(fxTime>.07){lightning();fxTime=0;}}else clearBolts();
   if(!a.done&&a.time>=a.impact){a.done=true;const result=game.resolve(a.id);if(result){
    if(a.triggered)log(heroName+' � '+skillName(game.skill));
    if(a.kind!=='guard'){
     play(a.target,athena&&a.triggered&&a.target==='hero'?'D4':'Hit');const p=new T.Vector3(fighters[a.target].model.position.x,2.4,.3).project(camera);$('damage').style.left=(p.x*.5+.5)*stage.clientWidth+'px';$('damage').style.top=(-p.y*.5+.5)*stage.clientHeight+'px';$('damage').textContent='−'+a.damage;
     log(`${a.actor==='zeus'?'Zeus':heroName} · ${a.kind==='judgment'?'Giudizio Divino':'attacco'}: ${a.damage} danni.`);
    }else log((a.actor==='hero'?heroName:'Zeus')+' in guardia: prossimo danno dimezzato.');ui();
   }}
   if(a.time>=a.duration){active=null;clearBolts();$('damage').textContent='';$('announcement').textContent=game.winner?(game.winner==='hero'?'VITTORIA DELL’AVVENTURIERO':'ZEUS TRIONFA'):'';for(const id of ['hero','zeus']){fighters[id].model.position.x=fighters[id].baseX;fighters[id].model.rotation.y=fighters[id].baseYaw;play(id,game.winner?(id===game.winner?'Victory':'Defeat'):'Idle');}ui();}
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
 function showSkill(id){if(!id||active||preview)return;if(focused)$('focus').click();play('hero',id);preview=fighters.hero.actions[id].getClip().duration;$('announcement').textContent=skillName(id);ui();}
 $('skill').onchange=ui;$('previewSkill').onclick=()=>showSkill($('skill').value);
 $('equipSkill').onclick=()=>{game.skill=$('skill').value;reset();if(game.skill){log(heroName+' equipaggia '+skillName(game.skill));showSkill(game.skill);}};
 $('attack').onclick=()=>start('attack');$('guard').onclick=()=>start('guard');$('judgment').onclick=()=>start('judgment');$('reset').onclick=reset;$('focus').onclick=()=>{focused=!focused;frameCamera();$('focus').textContent=focused?'TORNA ALL’ARENA':'OSSERVA ZEUS';};
 try{
  for(const [id,url,height,x,rotation] of [['hero',athena?'Athena.glb':'SamCombat.glb',athena?3.4:2.8,-1.55,.32],['zeus','ZeusCombat.glb',4.15,1.4,-.94]]){
   const response=await fetch(url,{signal:abort.signal});if(!response.ok)throw Error(`Asset ${id}: HTTP ${response.status}`);
   const gltf=await new GLTFLoader().parseAsync(await response.arrayBuffer(),location.href);if(disposed){free(gltf.scene);return;}
   const model=gltf.scene,box=new T.Box3().setFromObject(model);model.scale.setScalar(height/(box.max.y-box.min.y));model.position.set(x,-box.min.y*model.scale.x,0);model.rotation.y=rotation;scene.add(model);
   const mixer=new T.AnimationMixer(model),actions={};for(const c of gltf.animations)actions[c.name]=mixer.clipAction(c);
   for(const name of id==='hero'?(athena?['Waiting','Attack','Parry','D4','Hit','Victory','Defeat']:['Idle','Attack','Parry','C1','C2','C3','C4','C5']):['DivineJudgment'])if(!actions[name])throw Error(`Clip ${name} mancante per ${id}`);
   const hands=[];model.traverse(o=>{if(o.isBone&&/(Left|Right)Hand$/i.test(o.name))hands.push(o);});if(id==='zeus'&&hands.length!==2)throw Error('Mani Mixamo mancanti');fighters[id]={model,mixer,actions,hands,baseX:x,baseYaw:rotation};play(id,'Idle');
  }
  $('loading').hidden=true;document.body.dataset.ready='true';ui();resize();raf=requestAnimationFrame(tick);
 }catch(e){if(disposed)return;$('loading').hidden=false;$('loading').textContent='Impossibile caricare i personaggi. Ricarica la pagina.';console.error(e);dispose();}
}

import * as T from './vendor/three.module.js';

export const SKILL_CINEMATICS = Object.freeze({
  DivineJudgment: {
    title: 'GIUDIZIO DIVINO', character: 'zeus',
    image: 'zeus-cutin.webp', animationRate: 1.75, reactionRate: 2,
    cutinEnd: .8, impact: 1.1, duration: 1.82,
    effects: [
      {id:'thunder_aura_01', at:.15, end:.94, rate:1.5, anchor:'actorGround', height:4.9},
      {id:'thunder_charge_01', at:.28, end:.93, rate:3.2, anchor:'hands', height:2.6},
      {id:'thunder_strike_01', at:.94, end:1.76, rate:2.35, anchor:'targetGround', height:6.3},
      {id:'thunder_impact_01', at:1.1, end:1.8, rate:3.05, anchor:'targetBody', height:3.4},
    ],
  },
});

// Atlas coordinates are top-left pixels, texture UVs bottom-left; half-texel inset
// prevents neighboring flipbook cells bleeding at fractional mobile resolutions.
export function frameUV(frame, size) {
  return [(frame.x+.5)/size.w,1-(frame.y+frame.h-.5)/size.h,
    (frame.w-1)/size.w,(frame.h-1)/size.h];
}

export function createSkillDirector({scene,camera,renderer,stage}) {
  const base=new URL('./vfx/zeus/',import.meta.url);
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const root=new T.Group();root.name='SkillCinematicVFX';scene.add(root);
  const plane=new T.PlaneGeometry(1,1),cache=new Map(),textures=new Set();
  const pools=new Map();let current=null,disposed=false,extras=null;
  const light=new T.PointLight(0xa3ddff,0,9,2);root.add(light);
  const overlay=document.createElement('div');overlay.className='skill-cinema';
  overlay.setAttribute('aria-hidden','true');
  const dim=document.createElement('div');dim.className='skill-dim';
  const band=document.createElement('div');band.className='skill-cutin';
  const image=document.createElement('img');image.className='skill-cutin-image';image.alt='';
  const shade=document.createElement('div');shade.className='skill-cutin-shade';
  const title=document.createElement('div');title.className='skill-cutin-title';
  const sub=document.createElement('small');sub.textContent='ZEUS · POTERE DELL’OLIMPO';
  const words=document.createElement('strong');title.append(sub,words);
  const screenFlash=document.createElement('div');screenFlash.className='skill-flash';
  band.append(image,shade,title);overlay.append(dim,band,screenFlash);stage.append(overlay);
  const credit=document.createElement('a');credit.className='vfx-credit';
  credit.textContent='VFX: KanaWorks_AI (@KanaWorks_AI)';credit.href=new URL('LICENSE.md',base);credit.target='_blank';credit.rel='noopener';stage.append(credit);

  async function loadTexture(name) {
    const t=await new T.TextureLoader().loadAsync(new URL(name,base).href);
    if(disposed){t.dispose();throw new Error('Cinematic disposed');}
    t.colorSpace=T.SRGBColorSpace;t.generateMipmaps=false;
    t.minFilter=t.magFilter=T.LinearFilter;textures.add(t);renderer.initTexture(t);return t;
  }
  async function loadEffect(id) {
    if(cache.has(id))return cache.get(id);
    const promise=(async()=>{
      const name=id+'_add_1024';
      const json=async ext=>{const r=await fetch(new URL(name+ext,base));if(!r.ok)throw Error(`VFX ${id}: ${r.status}`);return r.json();};
      const [meta,atlas,map]=await Promise.all([json('.flipbook.json'),json('.atlas.json'),loadTexture(name+'.png')]);
      const frames=Object.values(atlas.frames);
      if(frames.length!==meta.frames||atlas.meta.size.w!==map.image.width||atlas.meta.size.h!==map.image.height)throw Error('Invalid VFX atlas: '+id);
      const material=new T.MeshBasicMaterial({map,transparent:true,depthWrite:false,depthTest:true,
        blending:meta.blend==='additive'?T.AdditiveBlending:T.NormalBlending,toneMapped:false,side:T.DoubleSide});
      // Additive variants already contain premultiplied RGB on black: do not
      // multiply by an invented alpha mask or treat them as straight-alpha PNGs.
      const group=new T.Group(),mesh=new T.Mesh(plane,material);mesh.renderOrder=8;mesh.frustumCulled=false;
      group.add(mesh);group.visible=false;root.add(group);
      return {meta,atlas,map,frames,group,mesh,lastFrame:-1};
    })();cache.set(id,promise);return promise;
  }
  async function preload(skill) {
    const cfg=SKILL_CINEMATICS[skill];if(!cfg||pools.has(skill))return;
    const [effects,ring,spark]=await Promise.all([
      Promise.all(cfg.effects.map(e=>loadEffect(e.id))),loadTexture('T_Ring.png'),loadTexture('T_Spark.png'),
      (async()=>{image.src=new URL(cfg.image,base).href;await image.decode();})(),
    ]);
    pools.set(skill,effects);
    const ringMaterial=new T.MeshBasicMaterial({map:ring,transparent:true,blending:T.AdditiveBlending,depthWrite:false,toneMapped:false,color:0xb9ddff,side:T.DoubleSide});
    const ringMesh=new T.Mesh(plane,ringMaterial);ringMesh.rotation.x=-Math.PI/2;ringMesh.visible=false;root.add(ringMesh);
    const positions=new Float32Array(18*3),geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.BufferAttribute(positions,3));
    const sparkMaterial=new T.PointsMaterial({map:spark,size:.14,color:0xc8e9ff,transparent:true,blending:T.AdditiveBlending,depthWrite:false,toneMapped:false});
    const points=new T.Points(geometry,sparkMaterial);points.frustumCulled=false;points.visible=false;root.add(points);extras={ring:ringMesh,points,positions};
    // Compile while the loading overlay is still visible, not on the first cast.
    for(const fx of effects){fx.group.visible=true;fx.mesh.material.opacity=0;}
    ringMesh.visible=points.visible=true;ringMaterial.opacity=sparkMaterial.opacity=0;
    if(renderer.compileAsync)await renderer.compileAsync(scene,camera);
    for(const fx of effects){fx.group.visible=false;fx.mesh.material.opacity=1;}
    ringMesh.visible=points.visible=false;
  }
  function restoreCamera() {
    if(!current)return;camera.position.copy(current.position);camera.quaternion.copy(current.rotation);camera.fov=current.fov;camera.updateProjectionMatrix();
  }
  function stop() {
    restoreCamera();current=null;overlay.style.visibility='hidden';light.intensity=0;
    for(const effects of pools.values())for(const fx of effects)fx.group.visible=false;
    if(extras){extras.ring.visible=extras.points.visible=false;}
    stage.dataset.cinematic='';delete stage.dataset.cinematicTime;stage.dataset.cutin='false';stage.dataset.vfx='';
  }
  function start(skill,actor,target) {
    stop();const cfg=SKILL_CINEMATICS[skill];if(!cfg||!pools.has(skill))return false;
    current={cfg,skill,actor,target,position:camera.position.clone(),rotation:camera.quaternion.clone(),fov:camera.fov};
    words.replaceChildren(...cfg.title.split(' ').map((word,i)=>{const span=document.createElement('span');span.textContent=(i?' ':'')+word;return span;}));overlay.style.visibility='visible';stage.dataset.cinematic=skill;return true;
  }
  function rebase(){if(current){current.position.copy(camera.position);current.rotation.copy(camera.quaternion);camera.fov=current.fov;camera.updateProjectionMatrix();}}
  const smooth=(a,b,x)=>T.MathUtils.smoothstep(x,a,b);
  const point=new T.Vector3(),other=new T.Vector3();
  function anchor(name) {
    const {actor,target}=current;
    if(name==='hands'){
      if(actor.hands.length===2){actor.hands[0].getWorldPosition(point);actor.hands[1].getWorldPosition(other);return point.lerp(other,.5);}
      return point.copy(actor.model.position).add(new T.Vector3(0,2.9,0));
    }
    point.copy((name==='actorGround'?actor:target).model.position);point.y=name==='targetBody'?1.65:.04;return point;
  }
  function update(time) {
    if(!current)return;
    const {cfg,actor,target}=current;
    stage.dataset.cinematicTime=time.toFixed(3);
    const entrance=smooth(0,.13,time),exit=smooth(.65,cfg.cutinEnd,time);
    band.style.visibility=time<cfg.cutinEnd?'visible':'hidden';
    band.style.transform=`translateX(${reduced?0:(1-entrance)*-105+exit*105}%)`;
    band.style.opacity=String(entrance*(1-exit));
    image.style.transform=reduced?'none':`scale(1.04) translateX(${time*1.6}%)`;
    dim.style.opacity=String(.32*entrance*(1-smooth(.65,.88,time)));
    stage.dataset.cutin=String(time<cfg.cutinEnd);
    const active=[];
    for(const [i,event] of cfg.effects.entries()){
      const fx=pools.get(current.skill)[i];fx.group.visible=time>=event.at&&time<event.end;
      if(!fx.group.visible)continue;
      let frame=Math.floor((time-event.at)*fx.meta.fps*event.rate);
      if(fx.meta.loop){const [lo,hi]=fx.meta.loop_range??[0,fx.meta.frames-1];frame=lo+frame%(hi-lo+1);}else frame=Math.min(frame,fx.meta.frames-1);
      const record=fx.frames[frame],uv=frameUV(record.frame,fx.atlas.meta.size);
      fx.map.offset.set(uv[0],uv[1]);fx.map.repeat.set(uv[2],uv[3]);
      const pivot=record.pivot??{x:fx.meta.pivot[0],y:fx.meta.pivot[1]};
      const width=event.height*record.sourceSize.w/record.sourceSize.h;
      fx.mesh.scale.set(width,event.height,1);fx.mesh.position.set((.5-pivot.x)*width,(pivot.y-.5)*event.height,0);
      fx.group.position.copy(anchor(event.anchor));
      if(fx.meta.orientation==='upright')fx.group.rotation.set(0,Math.atan2(camera.position.x-fx.group.position.x,camera.position.z-fx.group.position.z),0);
      else fx.group.quaternion.copy(camera.quaternion);
      fx.mesh.material.opacity=(reduced?.7:1)*(1-smooth(event.end-.12,event.end,time));active.push(event.id+':'+frame);
    }
    stage.dataset.vfx=active.join(',');
    const hit=time-cfg.impact;
    if(extras){
      const visible=hit>=0&&hit<.65;extras.ring.visible=extras.points.visible=visible;
      if(visible){
        extras.ring.position.copy(target.model.position);extras.ring.position.y=.06;
        extras.ring.scale.setScalar(1.2+hit*8);extras.ring.material.opacity=.65*(1-hit/.65);
        extras.points.position.copy(target.model.position);extras.points.position.y=1.2;
        for(let i=0;i<18;i++){const angle=i*2.399963;const speed=1.2+(i%5)*.4;
          extras.positions.set([Math.cos(angle)*hit*speed,.2+hit*(1+(i%4)*.55)-hit*hit*1.6,Math.sin(angle)*hit*speed],i*3);}
        extras.points.geometry.attributes.position.needsUpdate=true;extras.points.material.opacity=1-hit/.65;
      }
    }
    const pulse=hit>=0&&hit<.24?Math.exp(-hit*16):0;
    screenFlash.style.opacity=String(pulse*(reduced?.035:.12));
    light.position.copy(target.model.position).add(new T.Vector3(0,2,1));light.intensity=pulse*(reduced?2:6);
    restoreCamera();
    const zoom=smooth(0,.2,time)*(1-smooth(.95,cfg.duration,time));
    if(!reduced){
      camera.fov=current.fov-1.7*zoom;camera.position.x+=actor.baseX*.1*zoom;
      const shake=hit>=0&&hit<.18?.028*(1-hit/.18):0;
      camera.position.x+=Math.sin(hit*130)*shake;camera.position.y+=Math.sin(hit*97)*shake*.6;
    }
    camera.updateProjectionMatrix();
  }
  function dispose(){stop();disposed=true;for(const effects of pools.values())for(const fx of effects)fx.mesh.material.dispose();
    if(extras){extras.ring.material.dispose();extras.points.geometry.dispose();extras.points.material.dispose();}
    textures.forEach(t=>t.dispose());plane.dispose();scene.remove(root);overlay.remove();credit.remove();}
  stop();return {preload,start,update,stop,rebase,dispose};
}

export const COMBAT_RATE = 1.75;
export function animationRate(name) {
  if (name==='Idle'||name==='Waiting') return 1;
  return name==='Hit'?2:COMBAT_RATE;
}
const SOUNDS=['lightning_01','lightning_02','lightning_03','sword_swing_02','punch_01','sword_hit_shield_01','fireball_01','ice_spell_03','heal_01','explosion_big_01'];
export function combatCues({kind,actor,impact}) {
  if(kind==='judgment')return [
    {at:.15,sound:'lightning_01',gain:.2,length:.6},
    {at:.8,sound:'lightning_02',gain:.34,length:.42},
    {at:impact,sound:'lightning_03',gain:.5,length:.68},
    {at:impact,sound:'explosion_big_01',gain:.15,length:.65},
  ];
  if(kind==='guard')return [{at:impact,sound:'sword_hit_shield_01',gain:.35}];
  const cast=({zeus:'lightning_01',poseidon:'ice_spell_03',apollo:'heal_01',atena:'fireball_01',ade:'fireball_01',neris:'heal_01',nyra:'sword_swing_02'})[actor]||'sword_swing_02';
  return [{at:Math.max(.02,impact-.3),sound:cast,gain:.3,length:Math.min(.7,impact+.15)},
    {at:impact,sound:'punch_01',gain:.25}];
}

// One context and decoded buffer per sound; no autoplay before a user gesture.
export function createCombatAudio(container,stage) {
  const AudioContext=window.AudioContext||window.webkitAudioContext;
  let ctx=null,master=null,disposed=false,ready=false,unlocked=false,muted=false,queue=[],played=0;
  const buffers=new Map(),voices=new Set();
  try{muted=localStorage.getItem('kardrune-arena-muted')==='true';}catch{}
  const button=document.createElement('button');button.id='arena-audio';button.disabled=true;container.prepend(button);
  function sync(){button.textContent=muted?'♪ Muto':'♪ Audio';button.setAttribute('aria-pressed',String(!muted));button.setAttribute('aria-label',muted?'Attiva effetti audio':'Disattiva effetti audio');stage.dataset.audio=ready?(muted?'muted':'ready'):'unavailable';}
  function stopVoices(){for(const source of voices){try{source.stop();}catch{}}voices.clear();}
  function unlock(){unlocked=true;if(ctx?.state==='suspended'&&!document.hidden)ctx.resume().catch(()=>{});}
  button.onclick=()=>{unlock();muted=!muted;if(master)master.gain.setValueAtTime(muted?0:.7,ctx.currentTime);if(muted)stopVoices();try{localStorage.setItem('kardrune-arena-muted',String(muted));}catch{}sync();};
  async function preload(){
    if(!AudioContext)return sync();
    try{
      ctx=new AudioContext();master=ctx.createGain();master.gain.value=muted?0:.7;master.connect(ctx.destination);
      const base=new URL('./audio/',import.meta.url);
      await Promise.all(SOUNDS.map(async name=>{
        for(const extension of ['ogg','wav']){
          try{const response=await fetch(new URL(name+'.'+extension,base));if(!response.ok)throw Error('Missing audio');const buffer=await ctx.decodeAudioData(await response.arrayBuffer());if(!disposed)buffers.set(name,buffer);return;}catch(error){if(extension==='wav')throw error;}
        }
      }));
      if(disposed)return;ready=true;button.disabled=false;sync();
    }catch{sync();button.title='Audio non disponibile su questo browser';}
  }
  function play(sound,gain=.3,length=1){
    if(!ready||disposed||muted||!unlocked||document.hidden)return;
    const buffer=buffers.get(sound);if(!buffer)return;
    if(voices.size>=8){const oldest=voices.values().next().value;oldest.stop();voices.delete(oldest);}
    const source=ctx.createBufferSource(),volume=ctx.createGain();source.buffer=buffer;
    const now=ctx.currentTime,duration=Math.min(length,buffer.duration);
    volume.gain.setValueAtTime(0,now);volume.gain.linearRampToValueAtTime(gain,now+.008);
    volume.gain.setValueAtTime(gain,now+Math.max(.009,duration-.08));volume.gain.linearRampToValueAtTime(0,now+duration);
    source.connect(volume);volume.connect(master);voices.add(source);
    source.onended=()=>{voices.delete(source);source.disconnect();volume.disconnect();};
    source.start(now);source.stop(now+duration+.01);stage.dataset.audioPlayed=String(++played);
  }
  function begin(action){queue=combatCues(action).map(c=>({...c,done:false}));}
  function update(time){for(const cue of queue)if(!cue.done&&time>=cue.at){cue.done=true;play(cue.sound,cue.gain,cue.length);}}
  function reset(){queue=[];stopVoices();}
  function visibility(){if(document.hidden){stopVoices();ctx?.suspend().catch(()=>{});}else if(unlocked)unlock();}
  function dispose(){disposed=true;reset();buffers.clear();ctx?.close().catch(()=>{});button.remove();}
  sync();return {preload,unlock,begin,update,reset,visibility,dispose,heal:()=>play('heal_01',.25,.75),end:()=>{queue=[];}};
}

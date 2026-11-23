/** Local demonstration rules. Never connected to PvP, rewards, or saved data. */
export class Duel {
 constructor(){this.serial=0;this.reset();}
 reset(skill=this.skill){this.skill=skill;this.used=false;this.serial++;this.hp={hero:skill==="C3"?255:240,zeus:260};this.turn='hero';this.round=1;this.guarding={hero:false,zeus:false};this.firstZeus=true;this.pending=null;this.winner=null;}
 begin(kind){
  if(this.pending||this.winner||!['attack','guard','judgment'].includes(kind)||kind==='judgment'&&this.turn!=='zeus')return null;
  const actor=this.turn,target=actor==='hero'?'zeus':'hero';let damage=0;
  // D1 is Zeus's passive catalog bonus; judgment makes its storm VFX explicit.
  if(kind!=='guard')damage=actor==='hero'?38:Math.round(29*1.22)+(this.firstZeus?18:0);
  let triggered=false;
  if(kind!=='guard'){
   if(!this.used && actor==='hero' && (this.skill==='C1'||this.skill==='C4'&&this.hp.hero<120)){damage+=this.skill==='C1'?8:10;triggered=true;}
   if(!this.used && target==='hero' && this.skill==='D4'){damage=Math.round(damage*.70);triggered=true;}
   if(!this.used && target==='hero' && this.skill==='C2'){damage=Math.max(0,damage-8);triggered=true;}
   if(actor==='hero' && this.skill==='C5' && Math.random()<.03){damage*=2;triggered=true;}
  }
  if(this.guarding[target])damage=Math.ceil(damage*.5);
  return this.pending={id:++this.serial,actor,target,kind,damage,triggered};
 }
 resolve(id){
  const a=this.pending;if(!a||a.id!==id)return null;
  if(a.triggered && this.skill!=='C5')this.used=true;
  if(a.kind==='guard')this.guarding[a.actor]=true;
  else {this.hp[a.target]=Math.max(0,this.hp[a.target]-a.damage);this.guarding[a.target]=false;if(a.actor==='zeus')this.firstZeus=false;}
  if(!this.hp[a.target])this.winner=a.actor;
  this.pending=null;this.turn=a.target;if(this.turn==='hero')this.round++;return a;
 }
}

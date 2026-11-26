/** Local demonstration rules. Never connected to PvP, rewards, or saved data. */
export class Duel {
 constructor(roster={hero:"sam",zeus:"zeus"}){this.roster=roster;this.skills={};this.serial=0;this.reset();}
 maximum(id){return (id==='hero'?240:260)+(this.skills[id]==='C3'||id==='hero'&&this.skill==='C3'?15:0);}
 reset(skill=this.skill){this.skill=skill;this.used=false;this.spent={};this.serial++;this.hp={hero:this.maximum("hero"),zeus:this.maximum("zeus")};this.turn='hero';this.round=1;this.guarding={hero:false,zeus:false};this.firstZeus=true;this.pending=null;this.winner=null;}
 begin(kind){
  if(this.pending||this.winner||!['attack','guard','judgment'].includes(kind)||kind==='judgment'&&this.roster[this.turn]!=='zeus')return null;
  const actor=this.turn,target=actor==='hero'?'zeus':'hero';let damage=0;
  // D1 is Zeus's passive catalog bonus; judgment makes its storm VFX explicit.
  if(kind!=='guard')damage=this.roster[actor]!=='zeus'?38:Math.round(29*1.22)+(this.firstZeus?18:0);
  const skill=id=>this.skills[id] || (id==='hero'?this.skill:null);
  let triggered=false,owner;
  if(kind!=='guard'){
   const offense=skill(actor), defense=skill(target);
   if(!this.spent[actor] && (offense==='C1'||offense==='C4'&&this.hp[actor]<120)){damage+=offense==='C1'?8:10;owner=actor;}
   if(!this.spent[target] && defense==='C2'){damage=Math.max(0,damage-8);owner=target;}
   if(!this.spent[target] && defense==='D4'){damage=Math.round(damage*.7);owner=target;}
   if(offense==='C5' && Math.random()<.03){damage*=2;owner=actor;}
   triggered=!!owner;
  }
  if(this.guarding[target])damage=Math.ceil(damage*.5);
  return this.pending={id:++this.serial,actor,target,kind,damage,triggered,owner};
 }
 resolve(id){
  const a=this.pending;if(!a||a.id!==id)return null;
  if(a.owner && this.skills[a.owner]!=='C5')this.spent[a.owner]=true;
  if(a.triggered && this.skill!=='C5')this.used=true;
  if(a.kind==='guard')this.guarding[a.actor]=true;
  else {a.beforeHp=this.hp[a.target];this.hp[a.target]=Math.max(0,this.hp[a.target]-a.damage);this.guarding[a.target]=false;if(this.roster[a.actor]==='zeus')this.firstZeus=false;
   if(this.roster[a.actor]==='ade'){const cap=this.maximum(a.actor);const heal=Math.round(Math.min(a.damage,a.beforeHp)*.12);a.healed=Math.min(cap-this.hp[a.actor],heal);this.hp[a.actor]+=a.healed;}}
  if(!this.hp[a.target])this.winner=a.actor;
  this.pending=null;this.turn=a.target;if(this.turn==='hero')this.round++;return a;
 }
}

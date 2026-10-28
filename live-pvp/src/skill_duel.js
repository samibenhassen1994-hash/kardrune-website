import {SKILL_BY_ID} from '../../shared/skill_catalog.js';

const baseHp=stage=>[0,240,340,430][stage]||240;
const floor=Math.floor;
const percent=(value,rate)=>floor(value*rate/100);

export function resolveSkillDuel(cards,random=Math.random){
 const players=cards.map(card=>({
  card,skill:SKILL_BY_ID[card.skillId]||null,
  maxHp:baseHp(card.stage)+(card.skillId==='C3'?15:0),
  hp:baseHp(card.stage)+(card.skillId==='C3'?15:0),
  used:new Set(),attacks:0,successful:0,ascension:0,arcane:0,
  shield:card.skillId==='E2'||card.skillId==='U4'?2:card.skillId==='C2'||card.skillId==='R3'?1:0,
  dots:[],silence:0,freeze:0,weaken:0,cursed:false,sabotaged:false,
  guaranteed:false,tenacity:false,
 }));
 const events=[];let eventId=0;
 const event=(kind,source,target,detail={})=>{
  const skillId=detail.skillId||null;
  const type={skill:'skill_activate',dot:'status_tick',hit:'damage',extra_hit:'damage',
   counter:'damage',shield:'shield_block',skip:'status_tick'}[kind]||kind;
  events.push({eventId:++eventId,type,kind,actor:source,source,target,
   skillId,rarity:SKILL_BY_ID[skillId]?.rarity||null,
   name:SKILL_BY_ID[skillId]?.name||null,
   sourceHp:players[source]?.hp??null,targetHp:players[target]?.hp??null,...detail});
 };
 const activate=(owner,target,detail={})=>event('skill',owner,target,{skillId:players[owner].card.skillId,...detail});
 const active=i=>players[i].silence===0;
 const heal=(who,amount,skillId)=>{
  const p=players[who],before=p.hp;
  if(before<=0)return;
  p.hp=Math.min(p.maxHp,p.hp+amount);
  if(p.hp>before)event('heal',who,who,{skillId,heal:p.hp-before,hpBefore:before,hpAfter:p.hp,hp:p.hp});
 };
 const damage=(source,target,raw,{critical=false,skillId=null,extra=false,ignoreShield=false,counter=false,normalDamage=raw}={})=>{
  const attacker=players[source],defender=players[target];
  if(defender.hp<=0)return {actual:0,critical:false};
  if(!extra&&!counter&&active(target)&&defender.card.skillId==='R2'&&!defender.used.has('R2')&&random()<.25){
   defender.used.add('R2');activate(target,source,{status:'dodge'});
   event('dodge',target,target,{skillId:'R2',damage:0,hpBefore:defender.hp,hpAfter:defender.hp,hp:defender.hp});
   return {actual:0,critical:false};
  }
  let destiny=false;
  if(critical&&!extra&&!counter&&active(target)&&defender.card.skillId==='U2'&&!defender.used.has('U2')){
   defender.used.add('U2');destiny=true;critical=false;
   raw=Math.max(1,normalDamage);activate(target,source,{status:'critical_cancelled'});
  }
  let amount=raw;
  if(!ignoreShield&&active(target)&&defender.shield>0){
   const id=defender.card.skillId;
   if(id==='C2')amount=Math.max(0,amount-8);
   if(id==='R3')amount-=percent(amount,40);
   if(id==='E2')amount-=percent(amount,30);
   if(id==='U4')amount-=percent(amount,60);
   defender.shield--;
   activate(target,source,{status:'shield',blocked:raw-amount,charges:defender.shield});
   event('shield',target,target,{skillId:id,blocked:raw-amount,charges:defender.shield,
    hpBefore:defender.hp,hpAfter:defender.hp,hp:defender.hp});
  }
  if(amount>0)amount=Math.max(1,amount);
  const before=defender.hp;
  defender.hp=Math.max(0,before-amount);
  const actual=before-defender.hp;
  event(extra?'extra_hit':counter?'counter':'hit',source,target,{
   skillId,damage:actual,critical,hpBefore:before,hpAfter:defender.hp,hp:defender.hp,
   attackerHp:attacker.hp,extra,counter});
  if(defender.hp===0)event('knock_out',source,target,{hpBefore:before,hpAfter:0,hp:0});
  if(!extra&&!counter&&actual>0){
   if(active(target)&&defender.card.skillId==='C4'&&!defender.used.has('C4')&&
      defender.hp*2<defender.maxHp){
    defender.used.add('C4');defender.tenacity=true;activate(target,source,{status:'ready'});
   }
   if(active(target)&&defender.card.skillId==='E3'&&critical&&!defender.used.has('E3')){
    defender.used.add('E3');defender.guaranteed=true;activate(target,source,{status:'guaranteed_crit'});
   }
   if(active(target)&&defender.card.skillId==='N3'&&!defender.used.has('N3')){
    defender.used.add('N3');activate(target,source,{status:'counter'});
    damage(target,source,15,{skillId:'N3',counter:true,ignoreShield:true});
   }
  }
  if(destiny){
   const reply=Math.max(1,defender.card.attack);
   damage(target,source,reply,{skillId:'U2',counter:true,ignoreShield:true});
  }
  return {actual,critical};
 };
 for(let i=0;i<2;i++){
  if(players[i].card.skillId==='C3')activate(i,i,{status:'passive',hp:players[i].hp,maxHp:players[i].maxHp});
  if(players[i].card.skillId==='C5')activate(i,i,{status:'passive'});
 }
 const startHp=players.map(p=>p.hp),maxHp=players.map(p=>p.maxHp);
 let turn=random()<.5?0:1;
 for(let action=0;action<100&&players[0].hp>0&&players[1].hp>0;action++){
  const self=players[turn],enemy=players[1-turn],silenced=self.silence>0;
  for(const dot of [...self.dots]){
   const before=self.hp;
   self.hp=Math.max(0,self.hp-dot.amount);
   event('dot',dot.source,turn,{skillId:dot.skillId,damage:before-self.hp,
    hpBefore:before,hpAfter:self.hp,hp:self.hp,status:dot.skillId});
   dot.remaining--;
   if(dot.remaining<=0)self.dots.splice(self.dots.indexOf(dot),1);
   if(dot.remaining<=0)event('status_expire',dot.source,turn,{skillId:dot.skillId,status:'dot'});
   if(self.hp===0)event('knock_out',dot.source,turn,{skillId:dot.skillId,hpBefore:before,hpAfter:0,hp:0});
   if(self.hp===0)break;
  }
  if(self.hp===0)break;
  if(self.freeze>0){
   self.freeze--;
   event('skip',1-turn,turn,{skillId:'L5',status:'frozen',hp:self.hp});
   event('status_expire',1-turn,turn,{skillId:'L5',status:'frozen'});
   if(self.silence>0)self.silence--;
   turn=1-turn;continue;
  }
  self.attacks++;
  event('attack_start',turn,1-turn,{attackIndex:self.attacks,sourceHp:self.hp,targetHp:enemy.hp});
  const id=self.card.skillId,enabled=!silenced;
  let attack=self.card.attack;
  if(self.cursed)attack-=percent(self.card.attack,25);
  attack+=percent(self.card.attack,15*self.ascension);
  if(self.weaken>0)attack-=percent(attack,10);
  attack=Math.max(1,attack);
  let critical=self.guaranteed||random()<Math.max(0,Math.min(25,self.card.crit+(id==='C5'?3:0)-(self.sabotaged?10:0)))/100;
  if(self.guaranteed){self.guaranteed=false;activate(turn,1-turn,{status:'guaranteed_crit'});}
  let amount=attack*(critical?2:1),normalAmount=attack,ignoreShield=false;
  if(enabled&&id==='C1'&&self.attacks===1){amount+=8;normalAmount+=8;activate(turn,1-turn);}
  if(enabled&&id==='C4'&&self.tenacity){amount+=10;normalAmount+=10;self.tenacity=false;activate(turn,1-turn);}
  if(enabled&&id==='N1'&&self.hp*2<self.maxHp){
   const bonus=percent(attack,15);
   amount+=bonus*(critical?2:1);normalAmount+=bonus;activate(turn,1-turn);
  }
  if(enabled&&id==='R5'&&enemy.hp>self.hp){
   amount+=percent(amount,20);normalAmount+=percent(normalAmount,20);activate(turn,1-turn);
  }
  if(enabled&&id==='E4'&&self.attacks===1){
   amount+=percent(amount,20);normalAmount+=percent(normalAmount,20);ignoreShield=true;activate(turn,1-turn);
  }
  if(enabled&&id==='L2'&&!self.used.has('L2')&&enemy.hp*10<enemy.maxHp*3){
   amount+=percent(amount,50);normalAmount+=percent(normalAmount,50);
   self.used.add('L2');activate(turn,1-turn);
  }
  if(enabled&&id==='E5'&&!self.used.has('E5')){
   if(!critical)self.arcane=Math.min(30,self.arcane+10);
   if((critical||self.attacks>=5)&&self.arcane>0){
    amount+=self.arcane;normalAmount+=self.arcane;
    self.arcane=0;self.used.add('E5');activate(turn,1-turn,{status:'discharge'});
   }
  }
  const hit=damage(turn,1-turn,amount,{critical,skillId:null,ignoreShield,normalDamage:normalAmount});
  const actual=hit.actual;
  critical=hit.critical;
  if(actual>0&&enabled){
   self.successful++;
   if(id==='N2'&&!self.used.has('N2')){
    self.used.add('N2');enemy.dots.push({source:turn,skillId:'N2',amount:6,remaining:2});activate(turn,1-turn,{status:'poison',turns:2});
    event('status_apply',turn,1-turn,{skillId:'N2',status:'poison',turns:2});
   }
   if(id==='N5'&&!self.used.has('N5')){
    self.used.add('N5');enemy.weaken=2;activate(turn,1-turn,{status:'weaken',turns:2});
    event('status_apply',turn,1-turn,{skillId:'N5',status:'weaken',turns:2});
   }
   if(id==='R4'&&critical&&!self.used.has('R4')){
    self.used.add('R4');enemy.dots.push({source:turn,skillId:'R4',amount:12,remaining:2});activate(turn,1-turn,{status:'bleed',turns:2});
    event('status_apply',turn,1-turn,{skillId:'R4',status:'bleed',turns:2});
   }
   if(id==='L1'&&!self.used.has('L1')){
    self.used.add('L1');enemy.cursed=true;activate(turn,1-turn,{status:'curse'});
    event('status_apply',turn,1-turn,{skillId:'L1',status:'curse'});
   }
   if(id==='L3'&&!self.used.has('L3')){
    self.used.add('L3');enemy.silence=2;activate(turn,1-turn,{status:'silence',turns:2});
    event('status_apply',turn,1-turn,{skillId:'L3',status:'silence',turns:2});
   }
   if(id==='L4'&&!self.used.has('L4')){
    self.used.add('L4');enemy.sabotaged=true;activate(turn,1-turn,{status:'crit_down'});
    event('status_apply',turn,1-turn,{skillId:'L4',status:'crit_down'});
   }
   if(id==='L5'&&!self.used.has('L5')&&(critical||self.successful>=4)){
    self.used.add('L5');enemy.freeze=1;activate(turn,1-turn,{status:'freeze'});
    event('status_apply',turn,1-turn,{skillId:'L5',status:'freeze'});
   }
   if(id==='U3'&&!self.used.has('U3')){
    self.used.add('U3');const burn=Math.min(35,percent(enemy.maxHp,10));
    enemy.dots.push({source:turn,skillId:'U3',amount:burn,remaining:3});activate(turn,1-turn,{status:'burn',turns:3});
    event('status_apply',turn,1-turn,{skillId:'U3',status:'burn',turns:3});
   }
   if(id==='R1'){
    activate(turn,turn,{status:'vampirism'});heal(turn,percent(actual,12),'R1');
   }
  }
  if(players[0].hp>0&&players[1].hp>0&&enabled&&id==='E1'&&!self.used.has('E1')&&random()<.35){
   self.used.add('E1');activate(turn,1-turn,{status:'extra_hit'});
   damage(turn,1-turn,Math.max(1,percent(attack,50)),{skillId:'E1',extra:true});
  }
  if(players[0].hp>0&&players[1].hp>0&&enabled&&id==='U1'&&self.attacks%3===0&&self.attacks<=6){
   activate(turn,1-turn,{status:'extra_hit'});
   damage(turn,1-turn,Math.max(1,percent(attack,70)),{skillId:'U1',extra:true});
  }
  if(self.attacks===3&&enabled&&id==='N4'){
   activate(turn,turn,{status:'meditation'});heal(turn,20,'N4');
  }
  if(enabled&&id==='U5'&&self.ascension<4){
   self.ascension++;activate(turn,turn,{status:'ascension',stacks:self.ascension});
  }
  if(self.weaken>0&&--self.weaken===0)event('status_expire',1-turn,turn,{skillId:'N5',status:'weaken'});
  if(self.silence>0&&--self.silence===0)event('status_expire',1-turn,turn,{skillId:'L3',status:'silence'});
  turn=1-turn;
 }
 const hp=players.map(p=>p.hp);
 const winner=hp[0]===0&&hp[1]===0?'draw':hp[0]===0?1:hp[1]===0?0:
  hp[0]*maxHp[1]===hp[1]*maxHp[0]?'draw':hp[0]*maxHp[1]>hp[1]*maxHp[0]?0:1;
 event('round_end',-1,-1,{winner,hp:[...hp]});
 return {winner,log:events,hp,startHp,maxHp};
}

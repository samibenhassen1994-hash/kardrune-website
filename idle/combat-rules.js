/* Idle KardRune offline training: pure, testable battle rules. */
(function(root){
'use strict';
const STAGE_HP=Object.freeze([0,120,170,215]);
const STAGE_BASE_DAMAGE=Object.freeze([0,14,19,24]);
const TURN_MS=1200;
const MAX_CRIT=25;
const isAttack=x=>Number.isInteger(x)&&x>=1&&x<=100;
const validStage=s=>Number.isInteger(s)&&s>=1&&s<=3;
const isCrit=value=>Number.isInteger(value)&&value>=0&&value<=MAX_CRIT;
const hpForStage=stage=>STAGE_HP[stage]||STAGE_HP[1];
const normalizedRandom=fn=>Math.min(0.999999999,Math.max(0,Number(fn())||0));
const rollAttack=(random=Math.random)=>1+Math.floor(normalizedRandom(random)*100);
const rollCrit=(random=Math.random)=>Math.floor(normalizedRandom(random)*(MAX_CRIT+1));
function legacyAttack(id){
  // Stable migration for cards collected before attack stats existed.
  let h=2166136261;
  for(const c of String(id)){h=Math.imul(h^c.charCodeAt(0),16777619)}
  return 25+(h>>>0)%51; // 25–75 avoids destroying older player collections
}
function legacyCrit(id){
  // Consistent CRIT for cards saved before the CRIT mechanic was released.
  let h=2166136261;
  for(const c of String(id)){h=Math.imul(h^c.charCodeAt(0),16777619)}
  return 4+(h>>>0)%12; // 4–15% for pre-existing cards
}
function cardStats(stage,attack,crit=0){
  const s=validStage(stage)?stage:1;
  return {stage:s,attack:isAttack(attack)?attack:50,crit:isCrit(crit)?crit:0,maxHp:hpForStage(s)};
}
function pickEnemy(heroes,playerStage,random=Math.random){
  if(!heroes.length)throw Error('No enemy heroes');
  const hero=heroes[Math.floor(normalizedRandom(random)*heroes.length)];
  // 60% equal stage; otherwise one stage above/below when possible.
  const r=normalizedRandom(random);
  const offset=r<.6?0:r<.8?-1:1;
  const stage=Math.min(3,Math.max(1,(validStage(playerStage)?playerStage:1)+offset));
  return {id:hero.id,name:hero.name,...cardStats(stage,rollAttack(random),rollCrit(random))};
}
function newBattle(player,enemy,random=Math.random){
  if(!player||!enemy)throw Error('Two combatants required');
  const left={...player,crit:isCrit(player.crit)?player.crit:0,hp:hpForStage(player.stage),maxHp:hpForStage(player.stage)};
  const right={...enemy,crit:isCrit(enemy.crit)?enemy.crit:0,hp:hpForStage(enemy.stage),maxHp:hpForStage(enemy.stage)};
  return {player:left,enemy:right,turn:normalizedRandom(random)<.5?'player':'enemy',hits:0,status:'running',lastHit:null,winner:null};
}
function calculateDamage(stage,attack,random=Math.random){
  const base=STAGE_BASE_DAMAGE[validStage(stage)?stage:1];
  const atk=isAttack(attack)?attack:50;
  const variance=.9+normalizedRandom(random)*.2;
  return Math.max(1,Math.round((base+atk*.12)*variance));
}
function nextTurn(battle,random=Math.random){
  if(battle.status!=='running')return battle;
  const actor=battle.turn,target=actor==='player'?'enemy':'player';
  const baseDamage=calculateDamage(battle[actor].stage,battle[actor].attack,random);
  const critical=normalizedRandom(random)<battle[actor].crit/100;
  const damage=critical?baseDamage*2:baseDamage;
  const remaining=Math.max(0,battle[target].hp-damage);
  const winner=remaining===0?actor:null;
  return {...battle,
    [target]:{...battle[target],hp:remaining},
    turn:winner?null:target,
    hits:battle.hits+1,
    status:winner?'finished':'running',
    winner,
    lastHit:{actor,target,damage,critical,hp:remaining}
  };
}
const api=Object.freeze({STAGE_HP,STAGE_BASE_DAMAGE,TURN_MS,MAX_CRIT,isAttack,isCrit,validStage,hpForStage,rollAttack,rollCrit,legacyAttack,legacyCrit,cardStats,pickEnemy,newBattle,calculateDamage,nextTurn});
root.IDLE_COMBAT_RULES=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window!=='undefined'?window:globalThis);

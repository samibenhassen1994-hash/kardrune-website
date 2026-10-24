'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const combat=require('../combat-rules.js');
test('HP is fixed by stage',()=>{
 assert.deepEqual([1,2,3].map(combat.hpForStage),[240,340,430]);
});
test('ATK rolls cover inclusive 1-100',()=>{
 assert.equal(combat.rollAttack(()=>0),1);
 assert.equal(combat.rollAttack(()=>.999999),100);
});
test('normal hit equals card ATK regardless of Stage',()=>{
 for(const stage of [1,2,3]){
  for(const attack of [1,25,50,75,100]){
   assert.equal(combat.calculateDamage(stage,attack),attack);
  }
 }
});
test('opponents only use known cards and stages',()=>{
 const heroes=[{id:'sam',name:'Sam'},{id:'aria',name:'Aria'}];
 for(let i=0;i<100;i++){
  let step=0;const random=()=>{step++;return((i*11+step*23)%100)/100};
  const enemy=combat.pickEnemy(heroes,2,random);
  assert.ok(heroes.some(x=>x.id===enemy.id));
  assert.ok(enemy.stage>=1&&enemy.stage<=3);
  assert.ok(enemy.attack>=1&&enemy.attack<=100);
  assert.equal(enemy.maxHp,combat.hpForStage(enemy.stage));
 }
});
test('attacks alternate until knockout without negative HP',()=>{
 let b=combat.newBattle({name:'Sam',stage:1,attack:100},{name:'Lira',stage:1,attack:1},()=>0);
 let turns=0;
 while(b.status==='running'&&turns<100){
  const actor=b.turn;
  b=combat.nextTurn(b,()=>.5);turns++;
  if(b.status==='running')assert.notEqual(b.turn,actor);
 }
 assert.equal(b.status,'finished');
 assert.ok(b.winner==='player'||b.winner==='enemy');
 assert.ok(b.player.hp>=0&&b.enemy.hp>=0);
 assert.equal(combat.nextTurn(b),b);
});
test('legacy ATK is deterministic in a safe middle range',()=>{
 const val=combat.legacyAttack('sam:1');
 assert.equal(combat.legacyAttack('sam:1'),val);
 assert.ok(val>=25&&val<=75);
});

test('CRIT roll spans 0 to 25 percent',()=>{
 assert.equal(combat.rollCrit(()=>0),0);
 assert.equal(combat.rollCrit(()=>.999999),25);
 assert.ok(combat.isCrit(25));assert.ok(!combat.isCrit(26));
});
test('critical damage is exactly double noncritical damage',()=>{
 const player={name:'Sam',stage:1,attack:50,crit:25};
 const enemy={name:'Lira',stage:1,attack:50,crit:0};
 const normal=combat.nextTurn(combat.newBattle(player,enemy,()=>0),(()=>{let c=0;return()=>++c===1?.5:.99})());
 const critical=combat.nextTurn(combat.newBattle(player,enemy,()=>0),(()=>{let c=0;return()=>++c===1?.5:0})());
 assert.equal(normal.lastHit.critical,false);
 assert.equal(critical.lastHit.critical,true);
 assert.equal(normal.lastHit.damage,50);
 assert.equal(critical.lastHit.damage,100);
});
test('legacy crit remains within allowed range and deterministic',()=>{
 const crit=combat.legacyCrit('sam:1');
 assert.ok(crit>=0&&crit<=25);
 assert.equal(crit,combat.legacyCrit('sam:1'));
});

test('HP is reduced by ATK and remains positive after two 70 damage hits',()=>{
 const player={name:'Sam',stage:1,attack:70,crit:0};
 const enemy={name:'Lira',stage:1,attack:50,crit:0};
 let battle=combat.newBattle(player,enemy,()=>0);
 battle=combat.nextTurn(battle,()=>.9);
 assert.equal(battle.enemy.hp,170);
 battle=combat.nextTurn(battle,()=>.9);
 assert.equal(battle.player.hp,190);
 battle=combat.nextTurn(battle,()=>.9);
 assert.equal(battle.enemy.hp,100);
});
test('maximum critical cannot one-shot a full-health Stage 1',()=>{
 const battle=combat.newBattle({stage:1,attack:100,crit:25},{stage:1,attack:1,crit:0},()=>0);
 const after=combat.nextTurn(battle,()=>0);
 assert.equal(after.lastHit.damage,200);
 assert.equal(after.enemy.hp,40);
 assert.equal(after.status,'running');
});
test('damage in excess of remaining HP clamps health to zero',()=>{
 const battle=combat.newBattle({stage:1,attack:100,crit:25},{stage:1,attack:1,crit:0},()=>0);
 const first=combat.nextTurn(battle,()=>0);
 const second=combat.nextTurn(first,()=>.9);
 const third=combat.nextTurn(second,()=>0);
 assert.equal(third.enemy.hp,0);
 assert.equal(third.status,'finished');
 assert.equal(third.winner,'player');
});

test('ATK 58 deals exactly 58 or 116 and records true HP change',()=>{
 const a={stage:1,attack:58,crit:25},b={stage:1,attack:10,crit:0};
 const base=combat.newBattle(a,b,()=>0);
 const normal=combat.nextTurn(base,()=>.99);
 assert.equal(normal.lastHit.attack,58);
 assert.equal(normal.lastHit.damage,58);
 assert.equal(normal.lastHit.hpBefore,240);
 assert.equal(normal.lastHit.hp,182);
 assert.equal(normal.lastHit.actualHpLost,58);
 const critical=combat.nextTurn(base,()=>0);
 assert.equal(critical.lastHit.damage,116);
 assert.equal(critical.lastHit.hp,124);
 assert.equal(critical.lastHit.actualHpLost,116);
});

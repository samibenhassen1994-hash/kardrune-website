'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const combat=require('../combat-rules.js');
test('HP is fixed by stage',()=>{
 assert.deepEqual([1,2,3].map(combat.hpForStage),[120,170,215]);
});
test('ATK rolls cover inclusive 1-100',()=>{
 assert.equal(combat.rollAttack(()=>0),1);
 assert.equal(combat.rollAttack(()=>.999999),100);
});
test('stage bonuses and bounded attack damage',()=>{
 assert.equal(combat.calculateDamage(1,50,()=>.5),20);
 assert.equal(combat.calculateDamage(2,50,()=>.5),25);
 assert.equal(combat.calculateDamage(3,50,()=>.5),30);
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
 assert.equal(critical.lastHit.damage,normal.lastHit.damage*2);
});
test('legacy crit remains within allowed range and deterministic',()=>{
 const crit=combat.legacyCrit('sam:1');
 assert.ok(crit>=0&&crit<=25);
 assert.equal(crit,combat.legacyCrit('sam:1'));
});

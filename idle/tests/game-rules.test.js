'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const rules = require('../game-rules.js');
test('chance cannot be guaranteed even for the strongest stage',()=>{
 assert.equal(rules.practiceWinChance(79,3),.90);
 assert.ok(rules.practiceWinChance(0,1)>=.05);
});
test('ten rewarded duels maximum per local day',()=>{
 const time=new Date(2026,9,24,12,0,0).getTime();
 let daily={day:'',count:0};
 for(let i=0;i<10;i++){
  const result=rules.resolvePractice(daily,42,1,0,time);
  assert.equal(result.reward,100);
  daily=result.daily;
 }
 const extra=rules.resolvePractice(daily,42,1,0,time);
 assert.equal(extra.reward,0);
 assert.equal(extra.win,true);
 assert.equal(extra.daily.count,10);
});
test('reward limit resets on next local calendar day',()=>{
 const day1=new Date(2026,9,24,12,0,0).getTime();
 const day2=new Date(2026,9,25,12,0,0).getTime();
 const exhausted={day:rules.dayKey(day1),count:10};
 const next=rules.resolvePractice(exhausted,42,1,0,day2);
 assert.equal(next.reward,100);
 assert.equal(next.daily.count,1);
});
test('invalid persisted counters are sanitized',()=>{
 assert.equal(rules.safeCount(-1),0);
 assert.equal(rules.safeCount(NaN),0);
 assert.equal(rules.safeCount(1.2),0);
});

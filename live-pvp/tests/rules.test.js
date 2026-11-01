import test from 'node:test';
import assert from 'node:assert/strict';
import {buildHand,resolveDuel,resolveDuelFromStarter,pickWinner,matchComplete,hpByStage,rollInitiative,starterForRound} from '../src/rules.js';
test('three options, unplayed cards remain available',()=>{
 const deck=Array.from({length:9},(_,i)=>({id:'card:'+i}));
 assert.deepEqual(buildHand(deck,[],1).map(x=>x.id),['card:0','card:1','card:2']);
 assert.deepEqual(buildHand(deck,['card:1'],2).map(x=>x.id),['card:0','card:2','card:3']);
});
test('fixed HP values per evolution stage',()=>{
 assert.deepEqual([1,2,3].map(hpByStage),[240,340,430]);
});
test('exact ATK and double critical in server round',()=>{
 const a={stage:1,attack:58,crit:25},b={stage:1,attack:1,crit:0};
 let sequence=[0,.99,.99,.99,.99,0],i=0;
 const result=resolveDuel(a,b,()=>sequence[i++]??.99);
 const hits=result.log.filter(entry=>entry.kind==='hit'&&entry.actor===0);
 assert.equal(hits[0].damage,58);
 assert.equal(hits[0].hp,182);
 assert.equal(hits[1].damage,58);
 assert.equal(hits[2].damage,116);
});
test('best of three finishes at two wins or after three rounds',()=>{
 assert.equal(matchComplete([2,0],2),true);
 assert.equal(matchComplete([1,1],2),false);
 assert.equal(matchComplete([1,1],3),true);
});
test('match score winner and ties',()=>{
 assert.equal(pickWinner([5,4]),0);
 assert.equal(pickWinner([4,5]),1);
 assert.equal(pickWinner([4,4]),'draw');
});
test('server dice reroll ties and choose the higher D20',()=>{
 const values=[0,0,.20,.75];let index=0;
 const result=rollInitiative(()=>values[index++]);
 assert.deepEqual(result.attempts,[[1,1],[5,16]]);
 assert.deepEqual(result.rolls,[5,16]);
 assert.equal(result.starter,1);
});
test('round starter alternates from the authoritative dice winner',()=>{
 assert.deepEqual([1,2,3].map(round=>starterForRound(1,round)),[1,0,1]);
});
test('direct attacks alternate beginning with the declared starter',()=>{
 const a={stage:3,attack:60,crit:0},b={stage:3,attack:60,crit:0};
 const result=resolveDuelFromStarter(a,b,1,()=>.99);
 assert.deepEqual(result.log.filter(entry=>entry.kind==='attack_start').slice(0,4)
   .map(entry=>entry.actor),[1,0,1,0]);
});

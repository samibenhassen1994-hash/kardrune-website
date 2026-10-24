import test from 'node:test';
import assert from 'node:assert/strict';
import {buildHand,resolveDuel,pickWinner,hpByStage} from '../src/rules.js';
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
 assert.equal(result.log[0].damage,58);
 assert.equal(result.log[0].hp,182);
 assert.equal(result.log[2].damage,58);
 assert.equal(result.log[4].damage,116);
});
test('match score winner and ties',()=>{
 assert.equal(pickWinner([5,4]),0);
 assert.equal(pickWinner([4,5]),1);
 assert.equal(pickWinner([4,4]),'draw');
});

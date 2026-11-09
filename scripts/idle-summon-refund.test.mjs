import test from 'node:test';
import assert from 'node:assert/strict';
import {duplicateRefund} from '../functions/api/summon/decision.js';
for (const cost of [0,300,600]) {
 test(`summon original cost ${cost} controls keep refund`,()=>{
  assert.equal(duplicateRefund(cost,false),cost===0?0:100);
  assert.equal(duplicateRefund(cost,true),0);
 });
}
test('unknown or client-like cost cannot mint a refund',()=>{
 for(const cost of [undefined,null,-1,'300',1]) assert.equal(duplicateRefund(cost,false),0);
});

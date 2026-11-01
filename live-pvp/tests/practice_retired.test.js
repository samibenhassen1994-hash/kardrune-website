import test from 'node:test';
import assert from 'node:assert/strict';
import {onRequestPost} from '../../functions/api/practice.js';
test('retired Practice cannot award Shards',()=>{
 const result=onRequestPost();
 assert.equal(result.status,410);
 assert.equal(result.headers.get('cache-control'),'no-store');
});

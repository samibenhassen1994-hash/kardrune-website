import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {assertActivePlayer} from '../../functions/api/_lib/account_status.js';

test('economic mutations reject banned accounts',()=>{
 assert.throws(()=>assertActivePlayer({is_banned:1}),error=>
  error instanceof Response&&error.status===403);
});

test('every economic mutation is wired to the shared account guard',()=>{
 const files=[
  '../../functions/api/save.js',
  '../../functions/api/summon.js',
  '../../functions/api/summon/decision.js',
  '../../functions/api/practice.js',
  '../../functions/api/pvp/reward.js',
  '../../functions/api/_lib/pvp.js',
 ];
 for(const path of files){
  const source=readFileSync(new URL(path,import.meta.url),'utf8');
  assert.match(source,/requireActiveAccount\(/,path);
 }
});

test('active accounts pass and only bootstrap may allow a missing player',()=>{
 assert.doesNotThrow(()=>assertActivePlayer({is_banned:0}));
 assert.throws(()=>assertActivePlayer(null),error=>error instanceof Response&&error.status===403);
 assert.doesNotThrow(()=>assertActivePlayer(null,{allowMissing:true}));
});

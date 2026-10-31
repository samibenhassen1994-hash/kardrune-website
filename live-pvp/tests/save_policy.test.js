import test from 'node:test';
import assert from 'node:assert/strict';
import {isolateCompetitiveSave} from '../../functions/api/_lib/save_policy.js';
import {mergeGrantedSave} from '../../functions/api/_lib/skill_store.js';

test('cloud save cannot forge competitive progress or grants',()=>{
  const previous={
    name:'Old',avatar:'player',owned:['sam:1'],active:'sam:1',
    attacks:{'sam:1':40},crits:{'sam:1':4},skills:{'sam:1':{id:'C1'}},
    shards:700,duels:8,wins:3,pulls:5,
    practiceDaily:{day:'2026-10-31',count:2},pendingDuplicate:{rollId:'server'},
  };
  const forged={
    ...previous,name:'New',avatar:'guard',owned:['nyra:3'],active:'nyra:3',
    attacks:{'nyra:3':100},crits:{'nyra:3':25},skills:{},
    shards:999999,duels:900,wins:900,pulls:900,
    practiceDaily:{day:'2099-01-01',count:999},pendingDuplicate:null,
  };
  const isolated=isolateCompetitiveSave(forged,previous);
  assert.equal(isolated.name,'New');
  assert.equal(isolated.avatar,'guard');
  assert.deepEqual(isolated.owned,[]);
  assert.deepEqual(isolated.attacks,{});
  assert.deepEqual(isolated.crits,{});
  assert.deepEqual(isolated.skills,{});
  assert.equal(isolated.shards,700);
  assert.equal(isolated.duels,8);
  assert.equal(isolated.wins,3);
  assert.equal(isolated.pulls,5);
  assert.deepEqual(isolated.practiceDaily,{day:'2026-10-31',count:2});
  assert.deepEqual(isolated.pendingDuplicate,{rollId:'server'});
});

test('first cloud save begins with empty authoritative progress',()=>{
  const isolated=isolateCompetitiveSave({name:'New',avatar:'king',owned:['nyra:3'],
    shards:999,wins:99,duels:99,pulls:99,attacks:{},crits:{},skills:{}},null);
  assert.deepEqual(isolated.owned,[]);
  assert.equal(isolated.shards,0);
  assert.equal(isolated.wins,0);
  assert.equal(isolated.duels,0);
  assert.equal(isolated.pulls,0);
});

test('only server grants return to the normalized save',()=>{
  const isolated=isolateCompetitiveSave({name:'N',avatar:'player',owned:['nyra:3'],
    active:'nyra:3',shards:999,wins:99,duels:99,pulls:99,attacks:{},crits:{},skills:{}},null);
  const normalized=mergeGrantedSave(isolated,[{
    card_id:'sam:1',attack:99,crit:25,skill_id:'C1',rarity:'common',
    skill_version:1,source:'initial',
  }]);
  assert.deepEqual(normalized.owned,['sam:1']);
  assert.deepEqual(normalized.attacks,{'sam:1':50});
  assert.deepEqual(normalized.crits,{'sam:1':8});
  assert.equal(normalized.shards,0);
});

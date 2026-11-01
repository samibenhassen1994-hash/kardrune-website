import test from 'node:test';
import assert from 'node:assert/strict';
import {rewardForHistory,rewardAccess,rewardQuota,pendingRewardMatchIds} from '../../functions/api/_lib/pvp_reward_policy.js';

const completed={player_a:'a',player_b:'b',winner_uid:'a',reason:'completed'};
test('eligible winner earns 100 shards including opponent departure',()=>{
 assert.equal(rewardForHistory(completed,'a'),100);
 assert.equal(rewardForHistory(completed,'b'),0);
 assert.equal(rewardForHistory({...completed,winner_uid:null},'a'),0);
 assert.equal(rewardForHistory({...completed,reason:'replay_timeout'},'a'),100);
 assert.equal(rewardForHistory({...completed,reason:'opponent_disconnected'},'a'),100);
 assert.equal(rewardForHistory({...completed,reason:'invalid'},'a'),0);
});

test('pending reward discovery returns distinct valid match ids only',()=>{
 assert.deepEqual(pendingRewardMatchIds([
  {id:'m1'},{id:'m1'},{id:'m2'},{id:null},{id:3},
 ]),['m1','m2']);
});

test('reward farming limits repeated opponents and daily claims',()=>{
 const history={reason:'completed',player_a:'a',player_b:'b',winner_uid:'a'};
 assert.deepEqual(rewardAccess(history,'a',{total:9,againstOpponent:2}),
  {allowed:true,opponent:'b'});
 assert.deepEqual(rewardAccess(history,'a',{total:10,againstOpponent:2}),
  {allowed:false,reason:'daily_limit'});
 assert.deepEqual(rewardAccess(history,'a',{total:2,againstOpponent:3}),
  {allowed:false,reason:'opponent_limit'});
 assert.deepEqual(rewardAccess(history,'b',{total:0,againstOpponent:0}),
  {allowed:false,reason:'ineligible'});
});


test('quota counts claims in rolling 24 hours',()=>{
 const now=200000000,oldest=now-60000;
 assert.deepEqual(rewardQuota(3,oldest,now),{remaining:7,limit:10,nextRefreshAt:oldest+86400000});
 assert.deepEqual(rewardQuota(0,null,now),{remaining:10,limit:10,nextRefreshAt:null});
 assert.equal(rewardQuota(12,oldest,now).remaining,0);
});

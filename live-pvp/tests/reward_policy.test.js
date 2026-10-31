import test from 'node:test';
import assert from 'node:assert/strict';
import {rewardForHistory,rewardAccess} from '../../functions/api/_lib/pvp_reward_policy.js';

const completed={player_a:'a',player_b:'b',winner_uid:'a',reason:'completed'};
test('only the completed match winner earns 100 shards',()=>{
 assert.equal(rewardForHistory(completed,'a'),100);
 assert.equal(rewardForHistory(completed,'b'),0);
 assert.equal(rewardForHistory({...completed,winner_uid:null},'a'),0);
 assert.equal(rewardForHistory({...completed,reason:'replay_timeout'},'a'),0);
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

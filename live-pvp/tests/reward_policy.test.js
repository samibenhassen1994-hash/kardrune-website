import test from 'node:test';
import assert from 'node:assert/strict';
import {rewardForHistory} from '../../functions/api/_lib/pvp_reward_policy.js';

const completed={player_a:'a',player_b:'b',winner_uid:'a',reason:'completed'};
test('only the completed match winner earns 100 shards',()=>{
 assert.equal(rewardForHistory(completed,'a'),100);
 assert.equal(rewardForHistory(completed,'b'),0);
 assert.equal(rewardForHistory({...completed,winner_uid:null},'a'),0);
 assert.equal(rewardForHistory({...completed,reason:'replay_timeout'},'a'),0);
});

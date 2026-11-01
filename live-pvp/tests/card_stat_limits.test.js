import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CARD_STAT_LIMITS,
  effectiveCardStats,
  rollCardStats,
} from '../../shared/card_stat_limits.js';

test('every stage exposes the required attack and critical limits',()=>{
  assert.deepEqual(CARD_STAT_LIMITS,{
    1:{attack:[25,50],crit:[0,8]},
    2:{attack:[40,75],crit:[4,16]},
    3:{attack:[60,100],crit:[8,25]},
  });
});

test('historical values are bounded only when used',()=>{
  assert.deepEqual(effectiveCardStats(1,99,25),{attack:50,crit:8});
  assert.deepEqual(effectiveCardStats(2,1,0),{attack:40,crit:4});
  assert.deepEqual(effectiveCardStats(3,101,30),{attack:100,crit:25});
});

test('new rolls include both ends of each stage range',()=>{
  for(const stage of [1,2,3]){
    const limits=CARD_STAT_LIMITS[stage];
    assert.deepEqual(rollCardStats(stage,()=>0),{
      attack:limits.attack[0],crit:limits.crit[0],
    });
    assert.deepEqual(rollCardStats(stage,max=>max-1),{
      attack:limits.attack[1],crit:limits.crit[1],
    });
  }
});

import assert from 'node:assert/strict';
import {animationRate,combatCues} from '../idle/combat3d/combat-audio.mjs';
for(const name of ['Attack','Parry','Walking','Running','Victory','Defeat','Cast2','SpiritBond'])assert.equal(animationRate(name),1.75);
assert.equal(animationRate('Hit'),2);assert.equal(animationRate('Idle'),1);assert.equal(animationRate('Waiting'),1);
const zeus=combatCues({kind:'judgment',actor:'zeus',impact:1.1});assert.deepEqual(zeus.map(c=>c.at),[.15,.8,1.1,1.1]);assert(zeus.every(c=>c.gain<=.5));
const guard=combatCues({kind:'guard',actor:'sam',impact:.5});assert.equal(guard.length,1);assert.equal(guard[0].sound,'sword_hit_shield_01');
console.log('PASS shared animation speed and audio cues');

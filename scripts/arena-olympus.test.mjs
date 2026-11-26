import assert from 'node:assert/strict';
import {Duel} from '../idle/combat3d/duel-state.mjs';
function hit(g){const a=g.begin('attack');return g.resolve(a.id);}
const p=new Duel({hero:'poseidon',zeus:'sam'});
assert.equal(hit(p).damage,54);assert.equal(hit(p).damage,27);assert.equal(hit(p).damage,38);assert.equal(hit(p).damage,38);
p.reset();assert.equal(hit(p).damage,54);
const a=new Duel({hero:'sam',zeus:'apollo'});assert.equal(hit(a).targetHealed,38);assert.equal(a.hp.zeus,260);hit(a);hit(a);assert.equal(a.hp.zeus,222);
a.reset();a.hp.zeus=20;hit(a);assert.equal(a.hp.zeus,0);assert.equal(a.winner,'hero');
const twin=new Duel({hero:'apollo',zeus:'apollo'});hit(twin);hit(twin);assert.equal(twin.hp.hero,240);assert.equal(twin.hp.zeus,260);
const guard=new Duel({hero:'poseidon',zeus:'sam'});guard.resolve(guard.begin('guard').id);assert.equal(hit(guard).damage,14);
console.log('PASS Olympus arena passives, limits, guard, reset and lethal damage');

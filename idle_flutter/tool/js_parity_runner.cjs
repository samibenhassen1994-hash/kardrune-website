'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, '../test/fixtures/rules_parity.json')));
const game = require(path.join(root, 'idle/game-rules.js'));
const combat = require(path.join(root, 'idle/combat-rules.js'));

for (const c of fixture.practice) assert.equal(game.practiceWinChance(c.power, c.stage), c.chance);
for (const c of fixture.legacy) {
  assert.equal(combat.legacyAttack(c.id), c.attack);
  assert.equal(combat.legacyCrit(c.id), c.crit);
}
console.log(`JS parity fixtures passed: ${fixture.practice.length + fixture.legacy.length} cases`);

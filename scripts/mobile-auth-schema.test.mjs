import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';

const migration = readFileSync(
  new URL('../migrations/0008_mobile_auth_handoff.sql', import.meta.url),
  'utf8',
);

test('0008 coexists with the existing PvP and player-name tables', () => {
  const db = new DatabaseSync(':memory:');
  try {
    db.exec('CREATE TABLE pvp_reward_claims (uid TEXT, match_id TEXT);');
    db.exec('CREATE TABLE player_name_choices (uid TEXT PRIMARY KEY, name TEXT);');
    db.exec(migration);
    db.exec(migration);
    const names = db.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    ).all().map(row => row.name);
    assert.deepEqual(names, [
      'mobile_auth_handoffs', 'player_name_choices', 'pvp_reward_claims',
    ]);
    db.prepare('INSERT INTO mobile_auth_handoffs VALUES (?,?,?)')
      .run('hash', 'uid-1', 200);
    assert.throws(() => db.prepare('INSERT INTO mobile_auth_handoffs VALUES (?,?,?)')
      .run('other-hash', 'uid-1', 200));
    const consume = db.prepare(
      'DELETE FROM mobile_auth_handoffs WHERE code_hash=? AND expires_at>? RETURNING uid',
    );
    assert.equal(consume.get('hash', 199)?.uid, 'uid-1');
    assert.equal(consume.get('hash', 199), undefined);
    db.prepare('INSERT INTO mobile_auth_handoffs VALUES (?,?,?)')
      .run('expired', 'uid-2', 100);
    assert.equal(consume.get('expired', 100), undefined);
  } finally {
    db.close();
  }
});

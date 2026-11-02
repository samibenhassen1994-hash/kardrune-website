import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';

test('deck migration preserves ordered cards and rejects stale device writes',()=>{
  const db=new DatabaseSync(':memory:');
  db.exec('CREATE TABLE players(uid TEXT PRIMARY KEY); INSERT INTO players VALUES (\'u\');');
  db.exec('CREATE TABLE pvp_decks(uid TEXT PRIMARY KEY REFERENCES players(uid), cards_json TEXT NOT NULL, updated_at INTEGER NOT NULL);');
  db.prepare('INSERT INTO pvp_decks VALUES(?,?,?)').run('u',JSON.stringify(['sam:1','lira:1','rhea:1']),1);
  db.exec(readFileSync(new URL('../migrations/0009_pvp_deck_revision.sql',import.meta.url),'utf8'));
  assert.deepEqual(JSON.parse(db.prepare('SELECT cards_json FROM pvp_decks WHERE uid=?').get('u').cards_json),['sam:1','lira:1','rhea:1']);
  assert.equal(db.prepare('SELECT revision FROM pvp_decks WHERE uid=?').get('u').revision,1);
  const update=db.prepare('UPDATE pvp_decks SET cards_json=?,revision=revision+1 WHERE uid=? AND revision=?');
  assert.equal(update.run(JSON.stringify(['rhea:1','sam:1']), 'u',1).changes,1);
  assert.equal(update.run(JSON.stringify(['lira:1']), 'u',1).changes,0);
  assert.equal(db.prepare('SELECT cards_json FROM pvp_decks WHERE uid=?').get('u').cards_json,JSON.stringify(['rhea:1','sam:1']));
  db.close();
});

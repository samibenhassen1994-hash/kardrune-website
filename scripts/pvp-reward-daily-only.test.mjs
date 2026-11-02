import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';

test('0010 keeps claims and allows ten wins against one opponent, never eleven',()=>{
  const db=new DatabaseSync(':memory:');
  db.exec('CREATE TABLE players(uid TEXT PRIMARY KEY); CREATE TABLE pvp_live_history(id TEXT PRIMARY KEY,player_a TEXT,player_b TEXT); CREATE TABLE pvp_reward_claims(uid TEXT,match_id TEXT,base_revision INTEGER,response_json TEXT,PRIMARY KEY(uid,match_id));');
  db.exec(readFileSync(new URL('../migrations/0006_pvp_reward_hardening.sql',import.meta.url),'utf8'));
  db.exec(readFileSync(new URL('../migrations/0010_pvp_rewards_daily_only.sql',import.meta.url),'utf8'));
  const history=db.prepare('INSERT INTO pvp_live_history VALUES(?,?,?)');
  const claim=db.prepare('INSERT INTO pvp_reward_claims(uid,match_id,base_revision,response_json,claimed_at) VALUES(?,?,?,?,?)');
  const now=1_800_000_000_000;
  for(let i=0;i<10;i++){
    history.run(`m${i}`,'a','b');
    claim.run('a',`m${i}`,1,'{}',now+i);
  }
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM pvp_reward_claims WHERE uid=?').get('a').n,10);
  history.run('m10','a','b');
  assert.throws(()=>claim.run('a','m10',1,'{}',now+10),/daily/);
  assert.throws(()=>claim.run('a','m9',1,'{}',now+10),/daily|UNIQUE/);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM pvp_reward_claims WHERE uid=?').get('a').n,10);
  db.close();
});

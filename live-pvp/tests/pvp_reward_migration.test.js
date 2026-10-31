import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';

const migration=readFileSync(new URL('../../migrations/0006_pvp_reward_hardening.sql',import.meta.url),'utf8');

function database(){
 const db=new DatabaseSync(':memory:');
 db.exec(`
  CREATE TABLE players(uid TEXT PRIMARY KEY);
  CREATE TABLE pvp_live_history(id TEXT PRIMARY KEY,player_a TEXT,player_b TEXT);
  CREATE TABLE pvp_reward_claims(
   uid TEXT NOT NULL,match_id TEXT NOT NULL,base_revision INTEGER NOT NULL,
   response_json TEXT NOT NULL,PRIMARY KEY(uid,match_id));
 `);
 db.exec(migration);
 return db;
}

test('migration atomically blocks a fourth reward against one opponent',()=>{
 const db=database(),now=1_800_000_000_000;
 const history=db.prepare('INSERT INTO pvp_live_history VALUES(?,?,?)');
 const claim=db.prepare('INSERT INTO pvp_reward_claims(uid,match_id,base_revision,response_json,claimed_at) VALUES(?,?,?,?,?)');
 for(let i=0;i<3;i++){
  history.run(`m${i}`,'a','b');
  claim.run('a',`m${i}`,1,'{}',now+i);
 }
 history.run('m3','a','b');
 assert.throws(()=>claim.run('a','m3',1,'{}',now+3),/opponent/);
 db.close();
});

test('migration atomically caps all rewards in a rolling day',()=>{
 const db=database(),now=1_800_000_000_000;
 const history=db.prepare('INSERT INTO pvp_live_history VALUES(?,?,?)');
 const claim=db.prepare('INSERT INTO pvp_reward_claims(uid,match_id,base_revision,response_json,claimed_at) VALUES(?,?,?,?,?)');
 for(let i=0;i<10;i++){
  history.run(`m${i}`,'a',`opponent-${i}`);
  claim.run('a',`m${i}`,1,'{}',now+i);
 }
 history.run('m10','a','last');
 assert.throws(()=>claim.run('a','m10',1,'{}',now+10),/daily/);
 db.close();
});

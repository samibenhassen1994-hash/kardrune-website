import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {ensureRankedSchema} from '../../functions/api/_lib/ranked_store.js';

async function fixture(){
 const db=new DatabaseSync(':memory:');
 db.exec(`PRAGMA foreign_keys=ON;
 CREATE TABLE players(uid TEXT PRIMARY KEY);
 CREATE TABLE demo_saves(uid TEXT PRIMARY KEY,revision INTEGER);
 CREATE TABLE pvp_live_history(id TEXT PRIMARY KEY,player_a TEXT REFERENCES players(uid),player_b TEXT REFERENCES players(uid),winner_uid TEXT REFERENCES players(uid),reason TEXT,completed_at INTEGER);
 CREATE TABLE pvp_reward_claims(uid TEXT REFERENCES players(uid),match_id TEXT REFERENCES pvp_live_history(id),base_revision INTEGER,response_json TEXT,claimed_at INTEGER,PRIMARY KEY(uid,match_id));
 INSERT INTO players VALUES('a'),('b'); INSERT INTO demo_saves VALUES('a',1),('b',1);`);
 const prepare=sql=>({run:async()=>db.prepare(sql).run(),first:async()=>db.prepare(sql).get()});
 await ensureRankedSchema({DB:{prepare,batch:async rows=>{for(const row of rows)await row.run();}}});
 db.exec(readFileSync(new URL('../../migrations/0013_idle_bot_history.sql',import.meta.url),'utf8'));
 return db;
}
function bot(db,id,outcome='win',points=0){db.prepare('INSERT INTO pvp_bot_history VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO NOTHING').run(id,'a','virtual:'+id,'Vael',outcome==='win'?2:0,outcome==='loss'?2:0,outcome,'completed',points,1800000000000);}
test('bot results preserve player FKs, apply once, share human daily wins and never rank a bot',async()=>{
 const db=await fixture();
 for(let i=0;i<3;i++)db.prepare('INSERT INTO pvp_live_history VALUES(?,?,?,?,?,?)').run('h'+i,'a','b','a','completed',1800000000000);
 for(let i=0;i<10;i++)bot(db,'m'+i);
 bot(db,'m0');
 assert.equal(db.prepare("SELECT points FROM pvp_rankings WHERE uid='a'").get().points,250);
 assert.equal(db.prepare("SELECT COUNT(*) n FROM pvp_rankings WHERE uid LIKE 'virtual:%'").get().n,0);
 assert.deepEqual(db.prepare('PRAGMA foreign_key_check').all(),[]);
 db.close();
});
test('losses use starting league, demote, draws do not change points, retries are inert',async()=>{
 for(const [start,penalty] of [[0,0],[100,5],[250,10],[500,15],[900,20],[1500,20]]){
  const db=await fixture();db.prepare('INSERT INTO pvp_rankings VALUES(?,0,?,0)').run('a',start);
  bot(db,'loss','loss',start);bot(db,'loss','loss',start);bot(db,'draw','draw',start);
  assert.equal(db.prepare("SELECT points FROM pvp_rankings WHERE uid='a'").get().points,Math.max(0,start-penalty));db.close();
 }
});
test('bot reward rejects other users, loss, stale revision, duplicate and shared quota',async()=>{
 const db=await fixture(),claim=db.prepare('INSERT INTO pvp_bot_reward_claims VALUES(?,?,?,?,?)');
 bot(db,'win');bot(db,'loss','loss');
 assert.throws(()=>claim.run('b','win',1,'{}',1800000000000),/ineligible/);
 assert.throws(()=>claim.run('a','loss',1,'{}',1800000000000),/ineligible/);
 assert.throws(()=>claim.run('a','win',2,'{}',1800000000000),/revision/);
 claim.run('a','win',1,'{}',1800000000000);
 assert.throws(()=>claim.run('a','win',1,'{}',1800000000000),/UNIQUE/);
 for(let i=0;i<9;i++){
  db.prepare('INSERT INTO pvp_live_history VALUES(?,?,?,?,?,?)').run('h'+i,'a','b','a','completed',1800000000000);
  db.prepare('INSERT INTO pvp_reward_claims VALUES(?,?,?,?,?)').run('a','h'+i,1,'{}',1800000000000);
 }
 bot(db,'extra');assert.throws(()=>claim.run('a','extra',1,'{}',1800000000000),/daily/);
 db.close();
});
test('human and bot forfeits apply starting-league penalty once without rewards',async()=>{
 const db=await fixture();
 db.exec("INSERT INTO pvp_rankings VALUES('a',0,100,0); INSERT INTO pvp_match_starts VALUES('human','a',250);");
 db.prepare('INSERT INTO pvp_live_history VALUES(?,?,?,?,?,?)').run('human','a','b','b','opponent_disconnected',1800000000000);
 assert.equal(db.prepare("SELECT points FROM pvp_rankings WHERE uid='a'").get().points,90);
 db.prepare('INSERT INTO pvp_bot_history VALUES(?,?,?,?,?,?,?,?,?,?)').run('bot','a','virtual:bot','Vael',0,1,'loss','replay_timeout',100,1800000000000);
 assert.equal(db.prepare("SELECT points FROM pvp_rankings WHERE uid='a'").get().points,85);
 assert.throws(()=>db.prepare('INSERT INTO pvp_bot_reward_claims VALUES(?,?,?,?,?)').run('a','bot',1,'{}',1800000000000),/ineligible/);
 db.close();
});

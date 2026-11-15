import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {rollCard} from '../functions/api/_lib/skill_store.js';
import {olympusPity} from '../functions/api/_lib/olympus_pity.js';
import {OLYMPUS_PITY_RATES} from '../shared/skill_catalog.js';
test('all ten progressive rates are exact; tenth guarantees a god with Stage 3 random stats',()=>{
 for(let pull=0;pull<10;pull++){
  let gods=0;for(let ticket=0;ticket<1000;ticket++){
   const sequence=[ticket,0,0,0,0,0,0,0];const card=rollCard(false,true,()=>sequence.shift()??0,pull);
   if(card.skill.id.startsWith('D')){gods++;assert.equal(card.attack,60);assert.equal(card.crit,8);}
  }assert.equal(gods,OLYMPUS_PITY_RATES[pull]);
 }
 const seq=[999,5,40,17];const max=rollCard(false,true,()=>seq.shift()??0,9);
 assert.equal(max.id,'apollo:3');assert.equal(max.attack,100);assert.equal(max.crit,25);
});
test('pity is persisted, account-specific, ignores standard pulls and resets after every god including duplicates',async()=>{
 const db=new DatabaseSync(':memory:');db.exec('CREATE TABLE summon_rolls(uid TEXT,roll_id TEXT,result_json TEXT,base_revision INTEGER,PRIMARY KEY(uid,roll_id))');
 const env={DB:{prepare:sql=>({bind:(...args)=>({first:async()=>db.prepare(sql).get(...args)})})}};
 const put=db.prepare('INSERT INTO summon_rolls VALUES(?,?,?,?)');
 for(let i=0;i<10;i++){
  const before=await olympusPity(env,'admin');assert.equal(before.nextPull,i+1);
  put.run('admin',String(i),JSON.stringify({cost:1200,card:{id:i===9?'zeus:3':'sam:1'}}),i);
  put.run('other',String(i),JSON.stringify({cost:1200}),i);
  put.run('admin','standard'+i,JSON.stringify({cost:300}),i);
 }
 assert.equal((await olympusPity(env,'admin')).nextPull,1);
 assert.equal((await olympusPity(env,'new')).nextPull,1);
 assert.throws(()=>put.run('admin','0','{"cost":1200}',0),/UNIQUE/);
 assert.equal((await olympusPity(env,'admin')).completed,0);
 put.run('admin','miss',JSON.stringify({cost:1200,card:{id:'sam:1'}}),10);
 assert.equal((await olympusPity(env,'admin')).completed,1);
 put.run('admin','duplicate',JSON.stringify({cost:1200,duplicate:true,card:{id:'athena:3'}}),11);
 assert.equal((await olympusPity(env,'admin')).completed,0);
 put.run('admin','next',JSON.stringify({cost:1200,card:{id:'sam:1'}}),12);
 assert.equal((await olympusPity(env,'admin')).nextPull,2);db.close();
});
test('admin grants are atomic, role checked, isolated, bounded and cannot be replayed',()=>{
 const db=new DatabaseSync(':memory:');db.exec(`PRAGMA foreign_keys=ON;
 CREATE TABLE players(uid TEXT PRIMARY KEY,is_banned INTEGER);INSERT INTO players VALUES('admin',0),('player',0);
 CREATE TABLE player_roles(uid TEXT,role TEXT);INSERT INTO player_roles VALUES('admin','admin');
 CREATE TABLE demo_saves(uid TEXT PRIMARY KEY,save_json TEXT,revision INTEGER,updated_at TEXT);
 INSERT INTO demo_saves VALUES('admin','{"shards":1500,"owned":["sam:1"]}',1,NULL),('player','{"shards":1500}',1,NULL);
 CREATE TABLE skill_wallets(uid TEXT PRIMARY KEY,shards INTEGER CHECK(shards<=999999999),updated_at INTEGER);
 INSERT INTO skill_wallets VALUES('admin',1500,0),('player',1500,0);
 CREATE TABLE forge_keys(uid TEXT,color TEXT,quantity INTEGER,PRIMARY KEY(uid,color));`);
 db.exec(readFileSync(new URL('../migrations/0017_admin_test_resources.sql',import.meta.url),'utf8'));
 const insert=db.prepare('INSERT INTO admin_test_resource_grants VALUES(?,?,?,?,?,0)');
 assert.throws(()=>insert.run('player','a',1,12000,50),/ADMIN_FORBIDDEN/);
 insert.run('admin','a',1,12000,50);
 assert.equal(db.prepare("SELECT shards FROM skill_wallets WHERE uid='admin'").get().shards,13500);
 assert.equal(db.prepare("SELECT sum(quantity) n FROM forge_keys WHERE uid='admin'").get().n,150);
 assert.throws(()=>insert.run('admin','a',2,12000,50),/UNIQUE/);
 assert.throws(()=>insert.run('admin','b',1,12000,50),/ADMIN_CONFLICT/);
 assert.throws(()=>insert.run('admin','b',2,100001,50),/CHECK/);
 db.exec("UPDATE players SET is_banned=1 WHERE uid='admin'");
 assert.throws(()=>insert.run('admin','b',2,12000,50),/ADMIN_FORBIDDEN/);
 assert.equal(db.prepare("SELECT shards FROM skill_wallets WHERE uid='player'").get().shards,1500);
 assert.equal(JSON.parse(db.prepare("SELECT save_json FROM demo_saves WHERE uid='admin'").get().save_json).owned[0],'sam:1');
 assert.equal(db.prepare('SELECT count(*) n FROM admin_test_resource_grants').get().n,1);
 assert.deepEqual(db.prepare('PRAGMA foreign_key_check').all(),[]);db.close();
});

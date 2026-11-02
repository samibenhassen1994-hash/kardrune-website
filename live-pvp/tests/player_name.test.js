import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {normalizeDisplayName,chooseNameOnce,chosenNameFor} from '../../functions/api/_lib/name_store.js';

function fixture(){
 const db=new DatabaseSync(':memory:');
 db.exec(`CREATE TABLE players(uid TEXT PRIMARY KEY,display_name TEXT,updated_at TEXT);
  CREATE TABLE demo_saves(uid TEXT PRIMARY KEY,save_json TEXT,revision INTEGER,updated_at TEXT);
  INSERT INTO players(uid,display_name) VALUES('u1','Old Firebase');
  INSERT INTO demo_saves(uid,save_json,revision) VALUES('u1','{"name":"Old","shards":900,"owned":["sam:1"]}',3);`);
 const wrap=stmt=>({
  bind(...args){const bound={
   first:async()=>stmt.get(...args),
   run:async()=>({meta:{changes:stmt.run(...args).changes}}),
  };return bound},
  run:async()=>stmt.run(),
 });
 const env={DB:{prepare:sql=>wrap(db.prepare(sql)),batch:async statements=>{
  db.exec('BEGIN');try{const out=[];for(const s of statements)out.push(await s.run());db.exec('COMMIT');return out}
  catch(e){db.exec('ROLLBACK');throw e}
 }}};
 return {db,env};
}

test('player names support translated alphabets but reject defaults and malformed text',()=>{
 assert.equal(normalizeDisplayName('Luna'),'Luna');
 assert.equal(normalizeDisplayName('李明月'),'李明月');
 for(const invalid of ['a','Runebearer','<script>','A\\nB','x'.repeat(17),null,'Luna Rosa',' Admin','Admin01','kardrune99','FUCK999','c4zzo','puttana','Scheiße','死ね','씨발','傻逼']){
  assert.equal(normalizeDisplayName(invalid),null,String(invalid));
 }
});

test('first name wins; subsequent attempts cannot change PvP identity or saved name',async()=>{
 const {db,env}=fixture();
 assert.deepEqual(await chooseNameOnce(env,'u1','Luna'),{chosen:true,name:'Luna'});
 assert.equal(await chosenNameFor(env,'u1'),'Luna');
 assert.equal(db.prepare('SELECT display_name FROM players WHERE uid=?').get('u1').display_name,'Luna');
 const row=db.prepare('SELECT save_json,revision FROM demo_saves WHERE uid=?').get('u1');
 assert.equal(JSON.parse(row.save_json).name,'Luna');
 assert.equal(JSON.parse(row.save_json).shards,900);
 assert.equal(row.revision,4);
 assert.deepEqual(await chooseNameOnce(env,'u1','Other'),{chosen:false,name:'Luna'});
 assert.equal(db.prepare('SELECT display_name FROM players WHERE uid=?').get('u1').display_name,'Luna');
 assert.equal(db.prepare('SELECT revision FROM demo_saves WHERE uid=?').get('u1').revision,4);
 db.close();
});

test('legitimate unicode names without spaces stay usable',()=>{
 for(const name of ['Luna','Drago_7','玩家123','さくら','김하늘','María','Mädchen','李明月']){
  assert.equal(normalizeDisplayName(name),name,name);
 }
});

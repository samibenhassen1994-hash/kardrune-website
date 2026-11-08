import test from 'node:test';
import assert from 'node:assert/strict';
import {forgeOutcome,forgeAttempt,forgeState} from '../functions/api/_lib/forge.js';
for(const [color,p] of Object.entries({green:35,blue:55,red:75}))test(`${color} probability boundary`,()=>{
 const card={card_id:'sam:1',attack:30,crit:2,skill_id:'C1',rarity:'common',skill_version:1};
 assert.equal(forgeOutcome(card,color,'ATK',{min:1,max:5},max=>max===100?p-1:0).success,true);
 assert.equal(forgeOutcome(card,color,'ATK',{min:1,max:5},max=>max===100?p:0).success,false);
});

import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {choice} from '../functions/api/_lib/pvp.js';
function setup(){
 const sql=new DatabaseSync(':memory:');
 sql.exec(`PRAGMA foreign_keys=ON;CREATE TABLE players(uid TEXT PRIMARY KEY,is_banned INTEGER DEFAULT 0);INSERT INTO players VALUES('a',0),('b',0);
 CREATE TABLE demo_saves(uid TEXT PRIMARY KEY,save_json TEXT,revision INTEGER,updated_at TEXT);
 CREATE TABLE skill_grants(uid TEXT,card_id TEXT,attack INTEGER,crit INTEGER,skill_id TEXT,rarity TEXT,skill_version INTEGER,updated_at INTEGER,source TEXT DEFAULT 'initial',PRIMARY KEY(uid,card_id));`);
 sql.exec(readFileSync(new URL('../migrations/0015_idle_forge.sql',import.meta.url),'utf8'));
 const save={owned:['sam:1'],active:'sam:1',attacks:{'sam:1':48},crits:{'sam:1':7},skills:{'sam:1':{id:'C1',rarity:'common',v:1}},shards:1234};
 sql.prepare('INSERT INTO demo_saves VALUES(?,?,1,NULL)').run('a',JSON.stringify(save));
 sql.exec("INSERT INTO skill_grants VALUES('a','sam:1',48,7,'C1','common',1,0,'initial');INSERT INTO forge_keys VALUES('a','green',2)");
 const db={prepare(text){let args=[];return {bind(...values){args=values;return this;},async first(){return sql.prepare(text).get(...args)||null;},async all(){return {results:sql.prepare(text).all(...args)};},async run(){return sql.prepare(text).run(...args);}};}};
 return {sql,env:{DB:db}};
}
const req=(n=1,stat='ATK',revision=1)=>({requestId:n.toString(16).padStart(32,'0'),cardId:'sam:1',color:'green',stat,revision});
test('all stages respect caps and touch only requested stat',()=>{
 for(const [stage,attack,crit] of [[1,50,8],[2,75,16],[3,100,25]]){
  const c={card_id:`sam:${stage}`,attack:attack-1,crit:crit-1,skill_id:'R1',rarity:'rare'};
  const atk=forgeOutcome(c,'red','ATK',undefined,max=>max===100?0:max-1);
  assert.equal(atk.after.attack,attack);assert.equal(atk.after.crit,c.crit);assert.equal(atk.after.skillId,'R1');
  const crt=forgeOutcome(c,'red','CRT',undefined,max=>max===100?0:max-1);
  assert.equal(crt.after.crit,crit);assert.equal(crt.after.attack,c.attack);
  assert.throws(()=>forgeOutcome({...c,attack},'red','ATK'),/FORGE_CAP/);
 }
});
test('skill weights use existing stage tables and never keep previous skill',()=>{
 for(const stage of [1,2,3]){
  const c={card_id:`sam:${stage}`,attack:40,crit:8,skill_id:'R1',rarity:'rare'};
  const counts={};
  for(let ticket=0;ticket<1000;ticket++){
   const result=forgeOutcome(c,'red','SKILL',undefined,max=>max===1000?ticket:0);
   assert.notEqual(result.after.skillId,'R1');assert.equal(result.after.attack,c.attack);assert.equal(result.after.crit,c.crit);
   counts[result.after.rarity]=(counts[result.after.rarity]||0)+1;
  }
  assert.equal(counts.ultra,[0,2,5,10][stage]);
  assert.ok(counts.rare>counts.legendary&&counts.legendary>counts.ultra);
 }
});
test('atomic success persists to grants and friendly combat, retry charges once',async()=>{
 const {sql,env}=setup();const first=await forgeAttempt(env,'a',req(),()=>0);
 const retry=await forgeAttempt(env,'a',req(),()=>99);assert.deepEqual(retry,first);
 assert.equal(sql.prepare('SELECT quantity FROM forge_keys').get().quantity,1);
 const row=sql.prepare('SELECT * FROM demo_saves').get(),save=JSON.parse(row.save_json);
 assert.equal(row.revision,2);assert.equal(save.shards,1234);assert.equal(choice(save).attack,49);
 assert.equal(sql.prepare('SELECT attack FROM skill_grants').get().attack,49);
 await assert.rejects(forgeAttempt(env,'a',{...req(),stat:'CRT'}),/FORGE_INVALID/);
 assert.deepEqual(sql.prepare('PRAGMA foreign_key_check').all(),[]);sql.close();
});
test('failure consumes one key without changing any card values',async()=>{
 const {sql,env}=setup();const result=await forgeAttempt(env,'a',req(),()=>99);
 assert.equal(result.success,false);assert.deepEqual(result.before,result.after);
 assert.equal(sql.prepare('SELECT attack FROM skill_grants').get().attack,48);
 assert.equal(sql.prepare('SELECT quantity FROM forge_keys').get().quantity,1);sql.close();
});
test('concurrent requests cannot double-consume at one revision',async()=>{
 const {sql,env}=setup();const results=await Promise.allSettled([forgeAttempt(env,'a',req(1),()=>0),forgeAttempt(env,'a',req(2),()=>0)]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal(sql.prepare('SELECT quantity FROM forge_keys').get().quantity,1);
 assert.equal(sql.prepare('SELECT COUNT(*) n FROM forge_attempts').get().n,1);sql.close();
});
test('insufficient keys, banned accounts, pending duplicates and unowned cards do not mutate',async()=>{
 for(const mode of ['keys','ban','duplicate','owned']){
  const {sql,env}=setup();
  if(mode==='keys')sql.exec('UPDATE forge_keys SET quantity=0');
  if(mode==='ban')sql.exec('UPDATE players SET is_banned=1');
  if(mode==='duplicate')sql.exec(`UPDATE demo_saves SET save_json=json_set(save_json,'$.pendingDuplicate',json('{"rollId":"pending"}'))`);
  if(mode==='owned')sql.exec(`UPDATE demo_saves SET save_json=json_set(save_json,'$.owned',json('[]'))`);
  await assert.rejects(forgeAttempt(env,'a',req(),()=>0),/FORGE_/);
  assert.equal(sql.prepare('SELECT COUNT(*) n FROM forge_attempts').get().n,0);
  assert.equal(sql.prepare('SELECT revision FROM demo_saves').get().revision,1);sql.close();
 }
});
test('inventory isolates accounts and defaults to zero without free grants',async()=>{
 const {sql,env}=setup();const b=await forgeState(env,'b');assert.deepEqual(b.keys,{green:0,blue:0,red:0});assert.deepEqual(b.cards,[]);
 await assert.rejects(forgeAttempt(env,'b',req()),/FORGE_CARD/);sql.close();
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {ensureRankedSchema,rankedPage,ranking} from '../functions/api/_lib/ranked_store.js';

function fixture(){
 const db=new DatabaseSync(':memory:');
 db.exec(`PRAGMA foreign_keys=ON;
 CREATE TABLE players(uid TEXT PRIMARY KEY,display_name TEXT);
 CREATE TABLE demo_saves(uid TEXT PRIMARY KEY,revision INTEGER,save_json TEXT);
 CREATE TABLE pvp_live_history(id TEXT PRIMARY KEY,player_a TEXT,player_b TEXT,
  winner_uid TEXT,reason TEXT,completed_at INTEGER);
 `);
 for(let i=0;i<20;i++){
  const uid='p'+String(i).padStart(2,'0');
  db.prepare('INSERT INTO players(uid,display_name) VALUES(?,?)').run(uid,'Player '+i);
  db.prepare('INSERT INTO demo_saves(uid,revision,save_json) VALUES(?,?,?)')
   .run(uid,1,'{}');
 }
 const prepared=sql=>({
  bind(...args){const stmt=db.prepare(sql);return{
   run:async()=>stmt.run(...args),
   all:async()=>({results:stmt.all(...args)}),
   first:async()=>stmt.get(...args),
  }},
  run:async()=>db.prepare(sql).run(),
  all:async()=>({results:db.prepare(sql).all()}),
  first:async()=>db.prepare(sql).get(),
 });
 const env={DB:{
  prepare:prepared,
  batch:async statements=>{db.exec('BEGIN');try{
   const result=[];for(const stmt of statements)result.push(await stmt.run());
   db.exec('COMMIT');return result;
  }catch(e){db.exec('ROLLBACK');throw e}},
 }};
 return {db,env};
}

test('ranked pages return only 10 entries plus personal rank and can advance',async()=>{
 const {db,env}=fixture();
 for(let i=0;i<15;i++){
  const uid='p'+String(i).padStart(2,'0');
  db.prepare('INSERT INTO pvp_live_history VALUES(?,?,?,?,?,?)')
   .run('m'+i,uid,'p19',uid,'completed',i*86400000);
 }
 await ensureRankedSchema(env);
 const first=await rankedPage(env,'global','p19',0);
 assert.equal(first.leaders.length,10);
 assert.equal(first.hasMore,true);
 assert.equal(first.you.position,20);
 assert.equal(first.you.league,'Bronze');
 const second=await rankedPage(env,'global','p19',10);
 assert.equal(second.leaders.length,10);
 assert.equal(second.hasMore,false);
 const onlyBronze=await rankedPage(env,'league','p19',0);
 assert.equal(onlyBronze.leaders.length,10);
 assert.equal(onlyBronze.leaders[0].league,'Bronze');
 db.close();
});

test('auto-credit only confirmed outcomes, max 10/day and 3 per opponent',async()=>{
 const {db,env}=fixture();
 await ensureRankedSchema(env);
 const add=(id,a,b,winner,reason,ms=0)=>{
  db.prepare('INSERT INTO pvp_live_history VALUES(?,?,?,?,?,?)')
   .run(id,a,b,winner,reason,ms);
 };
 for(let i=0;i<6;i++)add('a'+i,'p00','p01','p00','completed',i);
 add('disconnect','p00','p02','p00','opponent_disconnected',9);
 add('draw','p00','p02',null,'completed',10);
 for(let i=0;i<30;i++)
  add('b'+i,'p00','p'+String(i%18+1).padStart(2,'0'),
   'p00','completed',100+i);
 const me=await ranking(env,'p00');
 assert.equal(me.mine.points,250);
 assert.equal(me.mine.wins,10);
 assert.equal(db.prepare('SELECT COUNT(*) as n FROM pvp_ranked_wins WHERE uid=?').get('p00').n,10);
 db.close();
});

import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {clanMutate,clanRead,validateClan,clanFailure} from '../functions/api/_lib/clans.js';
import {onRequestGet,onRequestPost} from '../functions/api/clans.js';
const migration=readFileSync(new URL('../migrations/0014_idle_clans.sql',import.meta.url),'utf8');
const id=n=>n.toString(16).padStart(32,'0');
function setup(){
 const sql=new DatabaseSync(':memory:');sql.exec(`PRAGMA foreign_keys=ON;CREATE TABLE players(uid TEXT PRIMARY KEY,display_name TEXT,avatar TEXT,is_banned INTEGER DEFAULT 0);INSERT INTO players(uid,display_name,avatar) VALUES('a','Sam','player'),('b','B','player'),('c','C','player');`);sql.exec(migration);sql.exec("CREATE TABLE player_roles(uid TEXT PRIMARY KEY REFERENCES players(uid),role TEXT);");
 let pending=Promise.resolve();
 const db={prepare(text){let args=[];return {bind(...values){args=values;return this;},async first(){return sql.prepare(text).get(...args)||null;},async all(){return {results:sql.prepare(text).all(...args)};},async run(){return sql.prepare(text).run(...args);}};},batch(stmts){const job=pending.then(async()=>{sql.exec('BEGIN');try{const out=[];for(const stmt of stmts)out.push(await stmt.run());sql.exec('COMMIT');return out;}catch(e){sql.exec('ROLLBACK');throw e;}});pending=job.catch(()=>{});return job;}};
 return {sql,db};
}
const create=(db,uid,n,name='Rune',now=10000000)=>clanMutate(db,uid,{action:'create',requestId:id(n),name,description:'Welcome',emblem:0},now);
const join=(db,uid,n,clan=1)=>clanMutate(db,uid,{action:'join',requestId:id(n),clanId:id(clan)},10000001);
const leave=(db,uid,n,clan=1)=>clanMutate(db,uid,{action:'leave',requestId:id(n),clanId:id(clan),confirm:true},10000002);
test('creation is atomic and idempotent; invite and current clan resolve without exposing UIDs',async()=>{
 const {db,sql}=setup();await create(db,'a',1);await create(db,'a',1);
 assert.equal(sql.prepare('SELECT COUNT(*) n FROM idle_clans').get().n,1);
 assert.equal(sql.prepare('SELECT COUNT(*) n FROM idle_clan_members').get().n,1);
 const code=sql.prepare('SELECT invite_code FROM idle_clans').get().invite_code;
 const detail=await (await clanRead(new Request('https://test/api/clans?invite='+code),db)).json();
 assert.equal(detail.clan.memberCount,1);assert.equal(detail.members[0].name,'Sam');assert.equal(detail.members[0].uid,undefined);
 const me=await (await clanRead(new Request('https://test/api/clans?me=1'),db,'a')).json();assert.equal(me.clan.id,id(1));
 assert.deepEqual(sql.prepare('PRAGMA foreign_key_check').all(),[]);sql.close();
});
test('normalized names, one clan per user and invalid inputs are enforced',async()=>{
 const {db,sql}=setup();await create(db,'a',1,'Rune');
 await assert.rejects(create(db,'b',2,'  RUNE  '),/name_key/);
 await assert.rejects(create(db,'a',3,'Other'),/CLAN_ALREADY_MEMBER/);
 for(const emblem of [-1,5,1.5])assert.throws(()=>validateClan({name:'Name',emblem}),/INVALID/);
 for(let emblem=0;emblem<5;emblem++)assert.equal(validateClan({name:'Name',emblem}).emblem,emblem);
 for(const name of ['', 'x'.repeat(25),'<script>','bad\nname'])assert.throws(()=>validateClan({name,emblem:0}),/INVALID/);
 assert.throws(()=>validateClan({name:'OK',description:'x'.repeat(161),emblem:0}),/INVALID/);
 assert.equal(sql.prepare('SELECT COUNT(*) n FROM idle_clan_requests').get().n,1);sql.close();
});
test('join retry cannot duplicate or rejoin after leave; oldest member inherits and last member dissolves',async()=>{
 const {db,sql}=setup();await create(db,'a',1);await join(db,'c',2);await join(db,'b',3);await join(db,'b',3);
 await leave(db,'a',4);assert.equal(sql.prepare('SELECT owner_uid FROM idle_clans').get().owner_uid,'b');
 await leave(db,'b',5);await join(db,'b',3);assert.equal(sql.prepare("SELECT COUNT(*) n FROM idle_clan_members WHERE uid='b'").get().n,0);
 await leave(db,'c',6);await leave(db,'c',6);assert.equal(sql.prepare('SELECT COUNT(*) n FROM idle_clans').get().n,0);
 assert.deepEqual(sql.prepare('PRAGMA foreign_key_check').all(),[]);sql.close();
});
test('competing memberships cannot both commit and retries cannot reuse a payload',async()=>{
 const {db,sql}=setup();await create(db,'a',1);await create(db,'b',2,'Other');
 const outcomes=await Promise.allSettled([join(db,'c',3),join(db,'c',4,2)]);
 assert.equal(outcomes.filter(o=>o.status==='fulfilled').length,1);
 assert.equal(outcomes.filter(o=>o.status==='rejected').length,1);
 assert.equal(sql.prepare("SELECT clan_id FROM idle_clan_members WHERE uid='c'").get().clan_id,id(1));
 const wrong=await join(db,'c',3,2);assert.equal(wrong.status,422);
 assert.equal(sql.prepare("SELECT COUNT(*) n FROM idle_clan_requests WHERE uid='c'").get().n,1);sql.close();
});
test('creation rate limit survives dissolution; missing clan and FK violations roll back receipts',async()=>{
 const {db,sql}=setup();await create(db,'a',1);await leave(db,'a',2);
 await assert.rejects(create(db,'a',3),/CLAN_CREATE_LIMIT/);
 await assert.rejects(join(db,'b',4,99),/FOREIGN KEY/);
 await create(db,'a',5,'Next',13600001);assert.equal(sql.prepare('SELECT COUNT(*) n FROM idle_clans').get().n,1);sql.close();
});
test('list pagination and request confirmation are bounded',async()=>{
 const {db,sql}=setup();await create(db,'a',1);
 const read=await (await clanRead(new Request('https://test/api/clans?offset=0'),db)).json();assert.equal(read.clans.length,1);assert.equal(read.hasMore,false);
 assert.equal((await clanRead(new Request('https://test/api/clans?offset=-1'),db)).status,400);
 assert.equal((await clanMutate(db,'a',{action:'leave',clanId:id(1),requestId:id(2)})).status,400);sql.close();
});
test('API requires verified Firebase auth for mutations; unconfigured schema fails closed',async()=>{
 const request=new Request('https://test/api/clans',{method:'POST',body:'{}'});
 assert.equal((await onRequestPost({request,env:{FIREBASE_PROJECT_ID:'test'}})).status,401);
 const get=await onRequestGet({request:new Request('https://test/api/clans'),env:{}});assert.equal(get.status,503);
 assert.equal(clanFailure(new Error('no such table: idle_clans')).status,503);
});

test('only game admin can delete clans; retries preserve players and creation limits',async()=>{
 const {db,sql}=setup();await create(db,'a',1);await join(db,'b',2);
 const before=sql.prepare('SELECT * FROM players ORDER BY uid').all();
 const body={action:'delete',clanId:id(1),requestId:id(9),confirm:true};
 assert.equal((await clanMutate(db,'a',body)).status,403);
 sql.exec("INSERT INTO player_roles VALUES('c','admin')");
 assert.equal((await clanMutate(db,'c',{...body,confirm:false})).status,400);
 const me=await (await clanRead(new Request('https://test/api/clans?me=1'),db,'c')).json();assert.equal(me.canDelete,true);
 assert.equal((await clanMutate(db,'c',body)).status,200);
 assert.equal((await clanMutate(db,'c',body)).status,200);
 assert.equal(sql.prepare('SELECT COUNT(*) n FROM idle_clans').get().n,0);
 assert.equal(sql.prepare('SELECT COUNT(*) n FROM idle_clan_members').get().n,0);
 assert.equal(sql.prepare('SELECT COUNT(*) n FROM idle_clan_creation_limits').get().n,1);
 assert.deepEqual(sql.prepare('SELECT * FROM players ORDER BY uid').all(),before);
 assert.deepEqual(sql.prepare('PRAGMA foreign_key_check').all(),[]);sql.close();
});

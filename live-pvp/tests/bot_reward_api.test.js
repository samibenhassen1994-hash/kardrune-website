import test from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {ensureRankedSchema} from '../../functions/api/_lib/ranked_store.js';
import {onRequestGet,onRequestPost} from '../../functions/api/pvp/reward.js';

test('authenticated API supports old schema, bot claim, concurrent retry and exact wallet credit',async t=>{
 const db=new DatabaseSync(':memory:');db.exec('PRAGMA foreign_keys=ON');
 const dir=new URL('../../migrations/',import.meta.url);
 for(const file of readdirSync(dir).filter(f=>/^00(0[1-9]|1[0-2])_.*\.sql$/.test(f)).sort())db.exec(readFileSync(new URL(file,dir),'utf8'));
 const prepare=(sql,args=[])=>({bind:(...args)=>prepare(sql,args),first:async()=>db.prepare(sql).get(...args),all:async()=>({results:db.prepare(sql).all(...args)}),run:async()=>db.prepare(sql).run(...args)});
 let queue=Promise.resolve();
 const env={FIREBASE_PROJECT_ID:'local-test',DB:{prepare,batch:stmts=>{
  const result=queue.then(async()=>{db.exec('BEGIN');try{for(const stmt of stmts)await stmt.run();db.exec('COMMIT');}catch(e){db.exec('ROLLBACK');throw e;}});
  queue=result.catch(()=>{});return result;
 }}};
 await ensureRankedSchema(env);
 for(const uid of ['a','b']){
  db.prepare('INSERT INTO players(uid) VALUES(?)').run(uid);
  db.prepare('INSERT INTO demo_saves(uid,save_json,revision) VALUES(?,?,1)').run(uid,'{"owned":[],"shards":0}');
  db.prepare('INSERT INTO skill_wallets(uid,shards,updated_at) VALUES(?,0,0)').run(uid);
  db.prepare('INSERT INTO practice_daily(uid,day,count) VALUES(?,0,0)').run(uid);
 }
 const keys=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
 const jwk=await crypto.subtle.exportKey('jwk',keys.publicKey);jwk.kid=crypto.randomUUID();jwk.alg='RS256';
 t.mock.method(globalThis,'fetch',async()=>Response.json({keys:[jwk]}));
 const token=async uid=>{
  const enc=x=>Buffer.from(JSON.stringify(x)).toString('base64url'),now=Math.floor(Date.now()/1000);
  const signed=enc({alg:'RS256',kid:jwk.kid})+'.'+enc({sub:uid,aud:env.FIREBASE_PROJECT_ID,iss:'https://securetoken.google.com/'+env.FIREBASE_PROJECT_ID,iat:now,exp:now+600});
  return signed+'.'+Buffer.from(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',keys.privateKey,new TextEncoder().encode(signed))).toString('base64url');
 };
 const tokens={a:await token('a'),b:await token('b')};
 const req=(uid,body)=>new Request('https://local/api/pvp/reward',{method:body?'POST':'GET',headers:{authorization:'Bearer '+tokens[uid],'content-type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 const get=uid=>onRequestGet({env,request:req(uid)}),claim=(uid,matchId,revision)=>onRequestPost({env,request:req(uid,{matchId,revision})});
 const human=crypto.randomUUID();db.prepare('INSERT INTO pvp_live_history(id,player_a,player_b,winner_uid,reason,score_a,score_b,completed_at) VALUES(?,?,?,?,?,2,0,?)').run(human,'a','b','a','completed',Date.now());
 assert.equal((await get('a')).status,200);assert.equal((await claim('a',human,1)).status,200);
 db.exec(readFileSync(new URL('0013_idle_bot_history.sql',dir),'utf8'));
 assert.equal(db.prepare("SELECT points FROM pvp_rankings WHERE uid='a'").get().points,25);
 db.exec(readFileSync(new URL('0013_idle_bot_history.sql',dir),'utf8'));
 await ensureRankedSchema(env);
 assert.equal(db.prepare("SELECT points FROM pvp_rankings WHERE uid='a'").get().points,25);
 const id=crypto.randomUUID();db.prepare('INSERT INTO pvp_bot_history VALUES(?,?,?,?,?,?,?,?,?,?)').run(id,'a','virtual:'+id,'Vael',2,0,'win','completed',0,Date.now());
 const pending=await (await get('a')).json();assert.deepEqual(pending.matchIds,[id]);assert.equal(pending.remaining,9);
 assert.equal((await claim('b',id,1)).status,403);
 const responses=await Promise.all([claim('a',id,2),claim('a',id,2)]);
 assert.ok(responses.some(r=>r.status===200));assert.ok(responses.every(r=>[200,409].includes(r.status)));
 const retry=await claim('a',id,2);assert.equal(retry.status,200);assert.equal((await retry.json()).alreadyClaimed,true);
 assert.equal(db.prepare("SELECT shards FROM skill_wallets WHERE uid='a'").get().shards,200);
 assert.equal(db.prepare("SELECT revision FROM demo_saves WHERE uid='a'").get().revision,3);
 assert.equal(db.prepare('SELECT COUNT(*) n FROM currency_ledger').get().n,2);
 assert.deepEqual(db.prepare('PRAGMA foreign_key_check').all(),[]);db.close();
});

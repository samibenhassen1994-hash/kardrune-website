import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {createSign,generateKeyPairSync} from 'node:crypto';
import test from 'node:test';
import {fileURLToPath} from 'node:url';
import {dirname,resolve} from 'node:path';
import {processNotifications} from '../src/index.js';
import {onRequestPost as createSubscription,onRequestDelete as deleteSubscription} from '../../functions/api/notifications/subscription.js';

const here=dirname(fileURLToPath(import.meta.url));

function database({maxQueries=Infinity}={}) {
  const sqlite=new DatabaseSync(':memory:');
  let queries=0;
  const tick=()=>{if(++queries>maxQueries)throw Error(`D1 query budget exceeded at ${queries}`);};
  sqlite.exec('PRAGMA foreign_keys=ON');
  for(let number=1;number<=5;number++) {
    const name=String(number).padStart(4,'0');
    const files={
      '0001':'0001_idle.sql','0002':'0002_pvp_friendly.sql',
      '0003':'0003_live_pvp.sql','0004':'0004_skill_system.sql',
      '0005':'0005_web_push.sql',
    };
    sqlite.exec(readFileSync(resolve(here,'../../migrations',files[name]),'utf8'));
  }
  return {
    sqlite,
    prepare(sql) {
      const statement=sqlite.prepare(sql);
      return {bind(...values) { return {
        async all() { tick();return {results:statement.all(...values)}; },
        async first() { tick();return statement.get(...values)??null; },
        async run() {
          tick();
          const result=statement.run(...values);
          return {meta:{changes:Number(result.changes)}};
        },
      }; }};
    },
    get queryCount() { return queries; },
  };
}

function seed(db,{enabled=1,createdAt=1_000_000}={}) {
  db.sqlite.exec(`
    INSERT INTO players(uid) VALUES ('user-a');
    INSERT INTO demo_saves(uid,save_json,revision) VALUES ('user-a','{}',1);
    INSERT INTO skill_wallets(uid,shards,updated_at) VALUES ('user-a',0,${createdAt});
    INSERT INTO notification_preferences(uid,topic,enabled,updated_at)
      VALUES ('user-a','free_pull',${enabled},${createdAt});
    INSERT INTO push_subscriptions(endpoint,uid,subscription_json,created_at,updated_at)
      VALUES ('https://fcm.googleapis.com/push/test','user-a',
      '{"endpoint":"https://fcm.googleapis.com/push/test","keys":{"p256dh":"key","auth":"auth"}}',${createdAt},${createdAt});
    INSERT INTO summon_rolls(uid,roll_id,base_revision,state,result_json,created_at)
      VALUES ('user-a','roll-1',1,'applied','{"cost":0}',${createdAt});
  `);
}

test('migration creates exactly one 12-hour reminder for a free pull',()=>{
  const db=database();
  seed(db);
  const event=db.sqlite.prepare('SELECT * FROM notification_events').get();
  assert.equal(event.id,'free_pull:user-a:roll-1');
  assert.equal(event.due_at,1_000_000+43_200_000);
  assert.equal(event.expires_at,event.due_at+21_600_000);
  db.sqlite.exec("UPDATE demo_saves SET revision=2 WHERE uid='user-a'; UPDATE skill_wallets SET shards=100 WHERE uid='user-a'");
  db.sqlite.prepare(`INSERT INTO summon_rolls(uid,roll_id,base_revision,state,result_json,created_at)
    VALUES ('user-a','roll-2',2,'applied','{"cost":100}',?)`).run(1_000_001);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS count FROM notification_events').get().count,1);
});

test('sender delivers once per event and endpoint',async()=>{
  const db=database();
  seed(db);
  const sent=[];
  const now=1_000_000+43_200_000;
  const env={DB:db,__sendPush:async(...args)=>sent.push(args)};
  await processNotifications(env,now);
  await processNotifications(env,now+300_000);
  assert.equal(sent.length,1);
  const payload=JSON.parse(sent[0][1]);
  assert.equal(payload.id,'free_pull:user-a:roll-1');
  assert.equal(payload.topic,'free_pull');
  assert.equal(db.sqlite.prepare('SELECT status FROM notification_deliveries').get().status,'sent');
});

test('disabled preferences block delivery and transient errors retry',async()=>{
  const db=database();
  seed(db,{enabled:0});
  const now=1_000_000+43_200_000;
  let attempts=0;
  const env={DB:db,__sendPush:async()=>{attempts++;if(attempts===1)throw Object.assign(Error('temporary'),{statusCode:503});}};
  await processNotifications(env,now);
  assert.equal(attempts,0);
  db.sqlite.exec("UPDATE notification_preferences SET enabled=1 WHERE uid='user-a'");
  await processNotifications(env,now+300_000);
  assert.equal(attempts,1);
  assert.equal(db.sqlite.prepare('SELECT status FROM notification_deliveries').get().status,'retry');
  await processNotifications(env,now+600_000);
  assert.equal(attempts,2);
  assert.equal(db.sqlite.prepare('SELECT status FROM notification_deliveries').get().status,'sent');
});

test('expired push endpoints are removed',async()=>{
  const db=database();
  seed(db);
  const now=1_000_000+43_200_000;
  await processNotifications({DB:db,__sendPush:async()=>{throw Object.assign(Error('gone'),{statusCode:410});}},now);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS count FROM push_subscriptions').get().count,0);
});

test('an expired endpoint is skipped for the rest of the loaded batch',async()=>{
  const db=database();
  seed(db);
  const now=1_000_000+43_200_000;
  db.sqlite.prepare(`INSERT INTO notification_events(id,uid,topic,due_at,expires_at,created_at)
    VALUES(?,?,'free_pull',?,?,?)`).run('free_pull:user-a:roll-2','user-a',now,now+21_600_000,2);
  let attempts=0;
  await processNotifications({DB:db,__sendPush:async()=>{
    attempts++;
    throw Object.assign(Error('gone'),{statusCode:410});
  }},now);
  assert.equal(attempts,1);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS count FROM push_subscriptions').get().count,0);
});

test('completed deliveries do not starve later due events',async()=>{
  const db=database();
  seed(db);
  const now=1_000_000+43_200_000;
  for(let index=2;index<=61;index++) {
    db.sqlite.prepare(`INSERT INTO notification_events(id,uid,topic,due_at,expires_at,created_at)
      VALUES(?,?,'free_pull',?,?,?)`).run(`free_pull:user-a:roll-${index}`,'user-a',now,now+21_600_000,index);
  }
  const insert=db.sqlite.prepare(`INSERT INTO notification_deliveries
    (event_id,endpoint,status,attempts,claimed_until,sent_at) VALUES(?,?,'sent',1,0,?)`);
  for(let index=1;index<=60;index++) {
    insert.run(`free_pull:user-a:roll-${index}`,'https://fcm.googleapis.com/push/test',now);
  }
  const sent=[];
  await processNotifications({DB:db,__sendPush:async(_sub,payload)=>sent.push(JSON.parse(payload))},now);
  assert.deepEqual(sent.map(item=>item.id),['free_pull:user-a:roll-61']);
});

test('a full sender batch stays inside the 50-query Free-plan budget',async()=>{
  const db=database({maxQueries:50});
  seed(db);
  const now=1_000_000+43_200_000;
  for(let index=2;index<=15;index++) {
    db.sqlite.prepare(`INSERT INTO notification_events(id,uid,topic,due_at,expires_at,created_at)
      VALUES(?,?,'free_pull',?,?,?)`).run(`free_pull:user-a:roll-${index}`,'user-a',now,now+21_600_000,index);
  }
  let sent=0;
  await processNotifications({DB:db,__sendPush:async()=>sent++},now);
  assert.equal(sent,15);
  assert.equal(db.queryCount,47);
});

function firebaseToken(uid,privateKey) {
  const encode=value=>Buffer.from(JSON.stringify(value)).toString('base64url');
  const now=Math.floor(Date.now()/1000);
  const head=encode({alg:'RS256',kid:'test-key'});
  const payload=encode({aud:'kardrune-test',iss:'https://securetoken.google.com/kardrune-test',
    sub:uid,iat:now-1,auth_time:now-1,exp:now+3600});
  const input=`${head}.${payload}`;
  const signature=createSign('RSA-SHA256').update(input).end().sign(privateKey).toString('base64url');
  return `${input}.${signature}`;
}

test('authenticated subscription deletion is isolated by Firebase uid',async()=>{
  const db=database();
  db.sqlite.exec("INSERT INTO players(uid) VALUES ('user-a'),('user-b')");
  const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});
  const jwk=publicKey.export({format:'jwk'});
  Object.assign(jwk,{kid:'test-key',alg:'RS256',use:'sig'});
  const previousFetch=globalThis.fetch;
  globalThis.fetch=async()=>new Response(JSON.stringify({keys:[jwk]}),{status:200});
  const env={DB:db,FIREBASE_PROJECT_ID:'kardrune-test',VAPID_PUBLIC_KEY:'A'.repeat(87)};
  const endpoint='https://fcm.googleapis.com/fcm/send/isolated';
  const request=(uid,method,body)=>new Request('https://example.test/api/notifications/subscription',{
    method,headers:{authorization:`Bearer ${firebaseToken(uid,privateKey)}`,'content-type':'application/json'},
    body:JSON.stringify(body),
  });
  try {
    const created=await createSubscription({request:request('user-a','POST',{subscription:{endpoint,
      keys:{p256dh:'A'.repeat(87),auth:'B'.repeat(22)}}}),env});
    assert.equal(created.status,200);
    const foreignDelete=await deleteSubscription({request:request('user-b','DELETE',{endpoint}),env});
    assert.equal(foreignDelete.status,200);
    assert.equal(db.sqlite.prepare('SELECT uid FROM push_subscriptions WHERE endpoint=?').get(endpoint).uid,'user-a');
    const ownerDelete=await deleteSubscription({request:request('user-a','DELETE',{endpoint}),env});
    assert.equal(ownerDelete.status,200);
    assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS count FROM push_subscriptions').get().count,0);
  } finally {
    globalThis.fetch=previousFetch;
  }
});

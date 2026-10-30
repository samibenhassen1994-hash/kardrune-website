import assert from 'node:assert/strict';
import test from 'node:test';
import {onRequestGet as getPreferences} from '../../functions/api/notifications/preferences.js';
import {onRequestPost as createSubscription} from '../../functions/api/notifications/subscription.js';
import {onRequestGet as getVapid} from '../../functions/api/notifications/vapid.js';

const env={FIREBASE_PROJECT_ID:'kardrune-test',DB:{}};

test('notification preferences require Firebase authentication',async()=>{
  const response=await getPreferences({request:new Request('https://example.test/api/notifications/preferences'),env});
  assert.equal(response.status,401);
});

test('subscription registration requires Firebase authentication',async()=>{
  const response=await createSubscription({
    request:new Request('https://example.test/api/notifications/subscription',{
      method:'POST',headers:{'content-type':'application/json'},body:'{}',
    }),env,
  });
  assert.equal(response.status,401);
});

test('VAPID endpoint exposes only the public key',async()=>{
  const publicKey='A'.repeat(87);
  const response=getVapid({env:{VAPID_PUBLIC_KEY:publicKey,VAPID_PRIVATE_KEY:'must-not-leak'}});
  assert.equal(response.status,200);
  const body=await response.json();
  assert.deepEqual(body,{enabled:true,publicKey});
  assert.equal(JSON.stringify(body).includes('must-not-leak'),false);
});

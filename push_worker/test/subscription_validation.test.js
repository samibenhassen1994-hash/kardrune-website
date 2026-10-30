import assert from 'node:assert/strict';
import test from 'node:test';
import {isPushEndpoint,validSubscription} from '../../functions/api/notifications/_lib.js';

test('only known HTTPS push services are accepted',()=>{
  assert.equal(isPushEndpoint('https://fcm.googleapis.com/fcm/send/id'),true);
  assert.equal(isPushEndpoint('https://web.push.apple.com/QWxwaGE'),true);
  assert.equal(isPushEndpoint('https://updates.push.services.mozilla.com/wpush/v2/id'),true);
  assert.equal(isPushEndpoint('http://fcm.googleapis.com/fcm/send/id'),false);
  assert.equal(isPushEndpoint('https://example.com/internal'),false);
  assert.equal(isPushEndpoint('https://fcm.googleapis.com:8443/fcm/send/id'),false);
});

test('subscription keys and endpoint are validated',()=>{
  const valid={endpoint:'https://fcm.googleapis.com/fcm/send/id',keys:{
    p256dh:'A'.repeat(87),auth:'B'.repeat(22),
  }};
  assert.equal(validSubscription(valid),true);
  assert.equal(validSubscription({...valid,keys:{...valid.keys,auth:'short'}}),false);
  assert.equal(validSubscription({...valid,endpoint:'https://example.com/push'}),false);
});

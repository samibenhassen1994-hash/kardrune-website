import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';

import {onRequestPost as issue} from '../functions/api/mobile-auth/issue.js';
import {onRequestPost as exchange} from '../functions/api/mobile-auth/exchange.js';
import {customToken} from '../functions/api/mobile-auth/_lib.js';

function b64(bytes) {
  return Buffer.from(bytes).toString('base64url');
}

test('mobile handoff verifies Firebase, binds UID, expires and consumes once', async () => {
  const keys = await webcrypto.subtle.generateKey(
    {name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256'},
    true, ['sign', 'verify'],
  );
  const jwk = await webcrypto.subtle.exportKey('jwk', keys.publicKey);
  const pkcs8 = await webcrypto.subtle.exportKey('pkcs8', keys.privateKey);
  const pem = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(pkcs8).toString('base64')}\n-----END PRIVATE KEY-----`;
  const now = Math.floor(Date.now() / 1000);
  const header = b64(JSON.stringify({alg: 'RS256', kid: 'test-key'}));
  const payload = b64(JSON.stringify({
    aud: 'idle-kardrune', iss: 'https://securetoken.google.com/idle-kardrune',
    sub: 'same-firebase-uid', exp: now + 600, iat: now, auth_time: now,
  }));
  const signed = `${header}.${payload}`;
  const signature = b64(await webcrypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', keys.privateKey, new TextEncoder().encode(signed),
  ));
  const rows = new Map();
  const db = {
    prepare(sql) {
      return {
        bind(...args) {
          return {
            async run() {
              if (sql.startsWith('INSERT')) {
                for (const [hash, row] of rows) {
                  if (row.uid === args[1]) rows.delete(hash);
                }
                rows.set(args[0], {uid: args[1], expiresAt: args[2]});
              }
            },
            async first() {
              const row = rows.get(args[0]);
              if (!row || row.expiresAt <= args[1]) return null;
              rows.delete(args[0]);
              return {uid: row.uid};
            },
          };
        },
      };
    },
  };
  const env = {
    DB: db, FIREBASE_PROJECT_ID: 'idle-kardrune',
    FIREBASE_SERVICE_ACCOUNT_EMAIL: 'test@example.invalid',
    FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY: pem,
  };
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify({
    keys: [{...jwk, kid: 'test-key', alg: 'RS256'}],
  }), {status: 200});
  try {
    const issued = await issue({
      request: new Request('https://kardrune.com/api/mobile-auth/issue', {
        method: 'POST', headers: {authorization: `Bearer ${signed}.${signature}`},
      }), env,
    });
    assert.equal(issued.status, 200);
    const {code} = await issued.json();
    assert.match(code, /^[A-Za-z0-9_-]{43}$/);
    assert.equal(rows.size, 1);
    assert.equal(rows.has(code), false, 'D1 must store only a hash');

    const redeem = origin => exchange({
      request: new Request('https://kardrune.com/api/mobile-auth/exchange', {
        method: 'POST', headers: {origin, 'content-type': 'application/json'},
        body: JSON.stringify({code}),
      }), env,
    });
    assert.equal((await redeem('https://evil.example')).status, 403);
    const first = await redeem('https://kardrune.com');
    assert.equal(first.status, 200);
    const {customToken} = await first.json();
    const customPayload = JSON.parse(Buffer.from(customToken.split('.')[1], 'base64url'));
    assert.equal(customPayload.uid, 'same-firebase-uid');
    assert.equal(await webcrypto.subtle.verify('RSASSA-PKCS1-v1_5',
      keys.publicKey, Buffer.from(customToken.split('.')[2], 'base64url'),
      new TextEncoder().encode(customToken.split('.').slice(0, 2).join('.'))), true);
    assert.equal((await redeem('https://kardrune.com')).status, 401);

    const next = await issue({
      request: new Request('https://kardrune.com/api/mobile-auth/issue', {
        method: 'POST', headers: {authorization: `Bearer ${signed}.${signature}`},
      }), env,
    });
    const nextCode = (await next.json()).code;
    const row = [...rows.values()][0];
    row.expiresAt = now - 1;
    const expired = await exchange({
      request: new Request('https://kardrune.com/api/mobile-auth/exchange', {
        method: 'POST', headers: {origin: 'https://kardrune.com'},
        body: JSON.stringify({code: nextCode}),
      }), env,
    });
    assert.equal(expired.status, 401);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('custom token signer supports escaped or multiline PEM secrets', async () => {
  const keys = await webcrypto.subtle.generateKey(
    {name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256'},
    true, ['sign', 'verify'],
  );
  const pkcs8 = await webcrypto.subtle.exportKey('pkcs8', keys.privateKey);
  const pem = '-----BEGIN PRIVATE KEY-----\n'
    + Buffer.from(pkcs8).toString('base64')
    + '\n-----END PRIVATE KEY-----';
  for (const secret of [pem, pem.replace(/\n/g, '\\n')]) {
    const token = await customToken('same-uid', {
      FIREBASE_PROJECT_ID: 'idle-kardrune',
      FIREBASE_SERVICE_ACCOUNT_EMAIL: 'test@example.invalid',
      FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY: secret,
    });
    const [header, payload, signature] = token.split('.');
    assert.equal(JSON.parse(Buffer.from(payload, 'base64url')).uid, 'same-uid');
    assert.equal(await webcrypto.subtle.verify(
      'RSASSA-PKCS1-v1_5', keys.publicKey,
      Buffer.from(signature, 'base64url'),
      new TextEncoder().encode(header + '.' + payload)), true);
  }
});

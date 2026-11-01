import {failure, json} from '../_lib/auth.js';
import {codeHash, customToken} from './_lib.js';

const allowedOrigins = new Set([
  'https://kardrune.com', 'https://www.kardrune.com',
]);

export async function onRequestPost({request, env}) {
  try {
    if (!allowedOrigins.has(request.headers.get('origin'))) {
      return json({error: 'Forbidden origin'}, 403);
    }
    if (!env.DB) return json({error: 'D1 not configured'}, 503);
    if (!env.FIREBASE_SERVICE_ACCOUNT_EMAIL ||
        !env.FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY) {
      return json({error: 'Mobile authentication not configured'}, 503);
    }
    if (Number(request.headers.get('content-length') || 0) > 256) {
      return json({error: 'Invalid code'}, 400);
    }
    const rawBody = await request.text();
    if (rawBody.length > 256) return json({error: 'Invalid code'}, 400);
    let body;
    try { body = JSON.parse(rawBody); } catch { body = null; }
    const code = body?.code;
    if (typeof code !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(code)) {
      return json({error: 'Invalid code'}, 400);
    }
    const now = Math.floor(Date.now() / 1000);
    const result = await env.DB.prepare(
      'DELETE FROM mobile_auth_handoffs WHERE code_hash=? AND expires_at>? RETURNING uid',
    ).bind(await codeHash(code), now).first();
    if (!result?.uid) return json({error: 'Code expired or already used'}, 401);
    const token = await customToken(result.uid, env);
    return json({customToken: token});
  } catch (error) { return failure(error); }
}

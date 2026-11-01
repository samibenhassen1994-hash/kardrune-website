import {userFromRequest, failure, json} from '../_lib/auth.js';
import {codeHash, randomCode} from './_lib.js';

export async function onRequestPost({request, env}) {
  try {
    const user = await userFromRequest(request, env);
    if (!env.DB) return json({error: 'D1 not configured'}, 503);
    if (!env.FIREBASE_SERVICE_ACCOUNT_EMAIL ||
        !env.FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY) {
      return json({error: 'Mobile authentication not configured'}, 503);
    }
    const code = randomCode();
    const now = Math.floor(Date.now() / 1000);
    const expiresAt = now + 60;
    await env.DB.prepare(
      'DELETE FROM mobile_auth_handoffs WHERE expires_at<=?',
    ).bind(now).run();
    await env.DB.prepare(
      'INSERT OR REPLACE INTO mobile_auth_handoffs (code_hash,uid,expires_at) VALUES (?,?,?)',
    ).bind(await codeHash(code), user.uid, expiresAt).run();
    return json({code, expiresAt});
  } catch (error) { return failure(error); }
}

import {json} from '../_lib/auth.js';
// Public VAPID key is intended for browsers; private key only lives in secrets.
export function onRequestGet({env}) {
  const key = env.VAPID_PUBLIC_KEY;
  return json({enabled:typeof key==='string' && /^[A-Za-z0-9_-]{80,100}$/.test(key),
    publicKey:typeof key==='string' ? key : null});
}

import { userFromRequest, json } from '../_lib/auth.js';

export const TOPICS = new Set(['free_pull']);
const allowedHosts = new Set([
  'fcm.googleapis.com', 'updates.push.services.mozilla.com',
  'web.push.apple.com', 'wns2-by3p.notify.windows.com',
]);
// Only accept real push-service endpoints. Do not turn a user's subscription
// into a Worker SSRF primitive.
export function isPushEndpoint(value) {
  if (typeof value !== 'string' || value.length > 2048) return false;
  try {
    const u = new URL(value);
    return u.protocol === 'https:' && !u.username && !u.password &&
      !u.port && (allowedHosts.has(u.hostname) ||
      u.hostname.endsWith('.push.apple.com') ||
      u.hostname.endsWith('.notify.windows.com') ||
      u.hostname.endsWith('.push.services.mozilla.com')) &&
      u.pathname.length > 1;
  } catch { return false; }
}
export function validSubscription(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input) ||
      !isPushEndpoint(input.endpoint) || !input.keys ||
      typeof input.keys !== 'object') return false;
  const {p256dh, auth} = input.keys;
  return typeof p256dh === 'string' && /^[\w-]{80,100}$/.test(p256dh) &&
    typeof auth === 'string' && /^[\w-]{20,40}$/.test(auth);
}
export async function authed(request, env) {
  const user = await userFromRequest(request, env);
  if (!env.DB) throw new Response('D1 not configured', {status:503});
  return user;
}
export async function readPayload(request) {
  const length = Number(request.headers.get('content-length') || 0);
  if (length > 4096) throw new Response('Payload too large', {status:413});
  let data;
  try { data = await request.json(); } catch { throw new Response('Invalid JSON', {status:400}); }
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      JSON.stringify(data).length > 4096)
    throw new Response('Invalid payload', {status:400});
  return data;
}
export { json };

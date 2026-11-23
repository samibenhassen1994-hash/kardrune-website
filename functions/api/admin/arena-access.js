import {userFromRequest, failure} from '../_lib/auth.js';
import {requireActiveAccount} from '../_lib/account_status.js';
import {requireAdmin} from '../portal/_lib.js';

const cookie = '__Host-kr-arena';
const ttl = 300;
function response(status, value) {
  const headers = {'Cache-Control':'private, no-store'};
  if (value !== undefined) headers['Set-Cookie'] =
    cookie+'='+value+'; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age='+(value ? ttl : 0);
  return new Response(null,{status,headers});
}
async function role(env,uid) {
  await requireActiveAccount(env,uid);
  await requireAdmin(env,uid);
}
export function ticket(request) {
  return (request.headers.get('Cookie') || '').split(';').map(s=>s.trim())
    .find(s=>s.startsWith(cookie+'='))?.slice(cookie.length+1) || '';
}
export async function digest(token) {
  const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token));
  return Array.from(new Uint8Array(bytes),v=>v.toString(16).padStart(2,'0')).join('');
}
export async function authorizeAsset(request,env) {
  const token=ticket(request);
  if (!/^[a-f0-9]{64}$/.test(token)) throw response(401);
  const row=await env.DB.prepare('SELECT uid FROM arena_admin_sessions WHERE id=? AND expires>?')
    .bind(await digest(token),Date.now()).first();
  if (!row) throw response(401);
  await role(env,row.uid);
}
export async function onRequest({request,env}) {
  try {
    const verb=request.method;
    if (!['GET','POST','DELETE'].includes(verb)) return response(405);
    if (verb!=='GET' && request.headers.get('Origin')!==new URL(request.url).origin) return response(403);
    if (verb==='DELETE') {
      const token=ticket(request);
      if (/^[a-f0-9]{64}$/.test(token)) await env.DB.prepare('DELETE FROM arena_admin_sessions WHERE id=?').bind(await digest(token)).run();
      return response(204,'');
    }
    const user=await userFromRequest(request,env);
    await role(env,user.uid);
    if (verb==='GET') return response(204);
    await env.DB.prepare('CREATE TABLE IF NOT EXISTS arena_admin_sessions (id TEXT PRIMARY KEY, uid TEXT NOT NULL, expires INTEGER NOT NULL)').run();
    const token=(crypto.randomUUID()+crypto.randomUUID()).replaceAll('-','');
    await env.DB.batch([
      env.DB.prepare('DELETE FROM arena_admin_sessions WHERE expires<=?').bind(Date.now()),
      env.DB.prepare('INSERT INTO arena_admin_sessions VALUES (?,?,?)').bind(await digest(token),user.uid,Date.now()+ttl*1000)
    ]);
    return response(204,token);
  } catch(e) {return response(failure(e).status);}
}

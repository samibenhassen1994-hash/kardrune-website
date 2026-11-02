import {userFromRequest, json} from '../_lib/auth.js';
import {requireActiveAccount} from '../_lib/account_status.js';

/**
 * Portal memberships live in the same D1 database as Idle KardRune.
 * No secondary passwords, role claims, or client-provided UIDs are trusted.
 */
export async function ensurePortalAccounts(env) {
  await env.DB.prepare(`CREATE TABLE IF NOT EXISTS website_accounts (
    uid TEXT PRIMARY KEY REFERENCES players(uid) ON DELETE CASCADE,
    joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`).run();
}

export async function portalUser(request, env, {register = false} = {}) {
  if (!env.DB) throw json({error:'Database unavailable'},503);
  const user=await userFromRequest(request,env);
  if (register) {
    await env.DB.prepare('INSERT OR IGNORE INTO players (uid,display_name) VALUES (?,?)')
      .bind(user.uid, user.name).run();
  }
  await requireActiveAccount(env,user.uid);
  await ensurePortalAccounts(env);
  if (register) {
    await env.DB.prepare(`INSERT INTO website_accounts(uid) VALUES (?)
      ON CONFLICT(uid) DO UPDATE SET last_seen_at=CURRENT_TIMESTAMP`)
      .bind(user.uid).run();
  }
  return user;
}

export async function requireAdmin(env, uid) {
  const row=await env.DB.prepare('SELECT role FROM player_roles WHERE uid=?').bind(uid).first();
  if(row?.role !== 'admin') throw json({error:'Forbidden'},403);
}

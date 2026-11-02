import {failure,json} from '../_lib/auth.js';
import {portalUser,requireAdmin} from './_lib.js';

// Server-enforced admin role. Read-only and paginated: never expose saves,
// Firebase credentials, tokens, passwords, or someone else's email address.
export async function onRequestGet({request,env}) {
  try {
    const actor=await portalUser(request,env);
    await requireAdmin(env,actor.uid);
    const url=new URL(request.url);
    const rawQuery=(url.searchParams.get('q')||'').trim().slice(0,64);
    const rawPage=Number(url.searchParams.get('page')||'1');
    const page=Number.isSafeInteger(rawPage)?Math.max(1,Math.min(rawPage,100)):1;
    const size=20, offset=(page-1)*size;
    const where=rawQuery?'WHERE p.uid=? OR p.display_name LIKE ? ESCAPE \'\\\'':'';
    // Escaped SQL LIKE wildcards preserve literal-search semantics.
    const like='%'+rawQuery.replace(/[\\%_]/g,'\\$&')+'%';
    const binds=rawQuery?[rawQuery,like]:[];
    const [accounts,players,idle,matches,tournaments,total,results]=await Promise.all([
      env.DB.prepare('SELECT COUNT(*) AS n FROM website_accounts').first(),
      env.DB.prepare('SELECT COUNT(*) AS n FROM players').first(),
      env.DB.prepare('SELECT COUNT(*) AS n FROM demo_saves').first(),
      env.DB.prepare('SELECT COUNT(*) AS n FROM pvp_matches').first(),
      env.DB.prepare('SELECT COUNT(*) AS n FROM tournaments').first(),
      env.DB.prepare(`SELECT COUNT(*) AS n FROM players p ${where}`).bind(...binds).first(),
      env.DB.prepare(`SELECT p.uid,p.display_name,p.created_at,p.is_banned,
         w.joined_at AS website_joined_at,
         CASE WHEN d.uid IS NULL THEN 0 ELSE 1 END AS has_idle_save,
         COALESCE(r.role,'player') AS role
         FROM players p
         LEFT JOIN website_accounts w ON w.uid=p.uid
         LEFT JOIN demo_saves d ON d.uid=p.uid
         LEFT JOIN player_roles r ON r.uid=p.uid
         ${where}
         ORDER BY p.created_at DESC,p.uid ASC LIMIT ? OFFSET ?`)
         .bind(...binds,size,offset).all()
    ]);
    return json({
      stats:{
        websiteAccounts:Number(accounts?.n)||0,
        knownPlayers:Number(players?.n)||0,
        idleSaves:Number(idle?.n)||0,
        pvpMatches:Number(matches?.n)||0,
        tournaments:Number(tournaments?.n)||0
      },
      users:(results.results||[]).map(row=>({
        uid:row.uid,displayName:row.display_name,createdAt:row.created_at,
        websiteJoinedAt:row.website_joined_at,
        hasIdleSave:row.has_idle_save===1,
        banned:row.is_banned===1,
        role:row.role
      })),
      page,total:Number(total?.n)||0,pageSize:size
    });
  }catch(error){return failure(error)}
}

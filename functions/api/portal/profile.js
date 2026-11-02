import {failure,json} from '../_lib/auth.js';
import {portalUser} from './_lib.js';

// Read-only, authenticated account and game-registration dashboard.
export async function onRequestGet({request,env}) {
  try {
    const user=await portalUser(request,env,{register:true});
    const [player,role,membership,idleSave,matchCount,entries]=await Promise.all([
      env.DB.prepare('SELECT display_name,avatar,created_at FROM players WHERE uid=?').bind(user.uid).first(),
      env.DB.prepare('SELECT role FROM player_roles WHERE uid=?').bind(user.uid).first(),
      env.DB.prepare('SELECT joined_at,last_seen_at FROM website_accounts WHERE uid=?').bind(user.uid).first(),
      env.DB.prepare('SELECT save_json,revision,updated_at FROM demo_saves WHERE uid=?').bind(user.uid).first(),
      env.DB.prepare('SELECT COUNT(*) AS count FROM pvp_matches WHERE player_a=? OR player_b=?')
        .bind(user.uid,user.uid).first(),
      env.DB.prepare('SELECT COUNT(*) AS count FROM tournament_entries WHERE uid=?').bind(user.uid).first()
    ]);
    // Only show save fields belonging to the verified Firebase UID.
    let idleProgress=null;
    if(idleSave) {
      try {
        const data=JSON.parse(idleSave.save_json);
        idleProgress={
          heroes:Array.isArray(data.owned)?data.owned.length:0,
          shards:Number.isSafeInteger(data.shards)?data.shards:null,
          revision:idleSave.revision,
          updatedAt:idleSave.updated_at
        };
      } catch {
        idleProgress={heroes:null,shards:null,revision:idleSave.revision,updatedAt:idleSave.updated_at};
      }
    }
    const idleRegistered=Boolean(idleSave || Number(matchCount?.count)>0 || Number(entries?.count)>0);
    return json({
      account:{
        uid:user.uid,
        email:user.email,
        displayName:player?.display_name||user.name,
        joinedAt:membership?.joined_at,
        lastSeenAt:membership?.last_seen_at,
        role:role?.role==='admin'?'admin':'player'
      },
      games:{
        idle:{
          registered:idleRegistered,
          name:'Idle KardRune',
          progress:idleProgress,
          matches:Number(matchCount?.count)||0,
          tournaments:Number(entries?.count)||0
        },
        android:{
          registered:null,
          name:'KardRune Android',
          status:'verification_not_connected'
        }
      }
    });
  }catch(error){return failure(error)}
}

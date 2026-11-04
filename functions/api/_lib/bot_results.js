// Read-only capability detection works before migration and during rollout.
export async function botResultsReady(db){
 const table=await db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='pvp_ranked_meta'").first();
 if(!table)return false;
 const marker=await db.prepare("SELECT value FROM pvp_ranked_meta WHERE key='bot_results_v1'").first();
 return marker?.value==='ready';
}
export const rewardClaimsSource=ready=>ready
 ? '(SELECT uid,match_id,claimed_at FROM pvp_reward_claims UNION ALL SELECT uid,match_id,claimed_at FROM pvp_bot_reward_claims)'
 : 'pvp_reward_claims';

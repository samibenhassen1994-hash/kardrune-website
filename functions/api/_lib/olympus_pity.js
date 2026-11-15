import {OLYMPUS_COST,OLYMPUS_PITY_RATES,OLYMPUS_IDS} from '../../../shared/skill_catalog.js';
// Immutable receipts and server save revisions include duplicates exactly once.
// Count only Event misses after the latest divine pull, even if it was discarded.
export async function olympusPity(env,uid){
 const ids=OLYMPUS_IDS.map(id=>`${id}:3`);
 const row=await env.DB.prepare(`SELECT COUNT(*) AS total FROM summon_rolls
  WHERE uid=? AND json_extract(result_json,'$.cost')=? AND base_revision>COALESCE(
   (SELECT MAX(base_revision) FROM summon_rolls WHERE uid=?
    AND json_extract(result_json,'$.cost')=?
    AND json_extract(result_json,'$.card.id') IN (${ids.map(()=>'?').join(',')})), -1)`)
  .bind(uid,OLYMPUS_COST,uid,OLYMPUS_COST,...ids).first();
 const completed=Math.min(9,Number(row?.total??0));
 return {completed,nextPull:completed+1,rate:OLYMPUS_PITY_RATES[completed]/10};
}

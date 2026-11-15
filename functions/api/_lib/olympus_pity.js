import {OLYMPUS_COST,OLYMPUS_PITY_RATES} from '../../../shared/skill_catalog.js';
// Existing immutable rolls include duplicates and retries only once. Reading
// this count with the save revision guard makes concurrent pulls serialize.
export async function olympusPity(env,uid){
 const row=await env.DB.prepare("SELECT COUNT(*) AS total FROM summon_rolls WHERE uid=? AND json_extract(result_json,'$.cost')=?").bind(uid,OLYMPUS_COST).first();
 const completed=Number(row?.total??0)%10;
 return {completed,nextPull:completed+1,rate:OLYMPUS_PITY_RATES[completed]/10};
}

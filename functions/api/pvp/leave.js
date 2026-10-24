import {context,json,failure} from '../_lib/pvp.js';
export async function onRequestPost({request,env}){
 try{
  const user=await context(request,env);
  // Clear completed match pointers; preserve immutable match history.
  await env.DB.prepare('DELETE FROM pvp_friendly_queue WHERE uid=? AND (match_id IS NULL OR match_id IN (SELECT id FROM pvp_friendly_matches))').bind(user.uid).run();
  return json({state:'idle'});
 }catch(e){return failure(e)}
}

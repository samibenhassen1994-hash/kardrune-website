import {userFromRequest,json,failure} from '../_lib/auth.js';
import {requireActiveAccount} from '../_lib/account_status.js';
import {ensureRankedSchema,rankedPage} from '../_lib/ranked_store.js';
import {LEAGUES} from '../_lib/ranked_leagues.js';

export async function onRequestGet({request,env}){
 try{
  if(!env.DB)return json({error:'Database unavailable'},503);
  const user=await userFromRequest(request,env);
  await requireActiveAccount(env,user.uid);
  const url=new URL(request.url);
  const offsetText=url.searchParams.get('offset')||'0';
  if(!/^(0|[1-9][0-9]{0,5})$/.test(offsetText))
   return json({error:'Invalid page offset'},400);
  const offset=Number(offsetText);
  if(offset>100000)return json({error:'Offset too large'},400);
  const scope=url.searchParams.get('scope')||'global';
  if(!['league','global'].includes(scope))
   return json({error:'Invalid ranking scope'},400);
  await ensureRankedSchema(env);
  const page=await rankedPage(env,scope,user.uid,offset);
  const claims=(await env.DB.prepare('SELECT league FROM pvp_league_claims WHERE uid=?').bind(user.uid).all()).results||[];
  return json({...page,scope,claimed:claims.map(x=>x.league),leagues:LEAGUES,
   yourPinnedPosition:scope==='league'?page.you.leaguePosition:page.you.position});
 }catch(error){return failure(error)}
}

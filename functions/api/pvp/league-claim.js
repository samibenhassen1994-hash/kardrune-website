import {userFromRequest,json,failure} from '../_lib/auth.js';
import {requireActiveAccount} from '../_lib/account_status.js';
import {ranking} from '../_lib/ranked_store.js';
import {LEAGUES} from '../_lib/ranked_leagues.js';
import {currentAccount} from '../_lib/skill_store.js';
export async function onRequestPost({request,env}){
 try{
  if(!env.DB)return json({error:'Database unavailable'},503);
  const user=await userFromRequest(request,env);
  await requireActiveAccount(env,user.uid);
  const body=await request.json();
  const league=LEAGUES.find(x=>x.name===body?.league&&x.reward>0);
  if(!league)return json({error:'Unknown milestone'},400);
  const ranked=await ranking(env,user.uid);
  if(ranked.mine.points<league.points)return json({error:'League not reached'},403);
  const already=await env.DB.prepare('SELECT league FROM pvp_league_claims WHERE uid=? AND league=?')
   .bind(user.uid,league.name).first();
  if(already)return json({alreadyClaimed:true,league:league.name});
  const account=await currentAccount(env,user.uid);
  if(!account)return json({error:'Cloud save unavailable'},503);
  const updated={...account.save,shards:account.save.shards+league.reward};
  if(!Number.isSafeInteger(updated.shards)||updated.shards>999999999)return json({error:'Wallet limit'},409);
  const now=Date.now();
  try {
   await env.DB.batch([
    env.DB.prepare('INSERT INTO pvp_league_claims(uid,league,points_at_claim,expected_revision,shards,claimed_at) VALUES(?,?,?,?,?,?)')
     .bind(user.uid,league.name,ranked.mine.points,account.revision,league.reward,now),
    env.DB.prepare('UPDATE demo_saves SET save_json=?,revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE uid=? AND revision=?')
     .bind(JSON.stringify(updated),user.uid,account.revision),
    env.DB.prepare('UPDATE skill_wallets SET shards=shards+?,updated_at=? WHERE uid=?')
     .bind(league.reward,now,user.uid),
    env.DB.prepare('INSERT INTO currency_ledger(id,uid,delta,reason) VALUES(?,?,?,?)')
     .bind('league:'+user.uid+':'+league.name,user.uid,league.reward,'pvp_league_milestone'),
   ]);
  }catch(e) {
   const claimed=await env.DB.prepare('SELECT league FROM pvp_league_claims WHERE uid=? AND league=?')
     .bind(user.uid,league.name).first();
   if(claimed)return json({alreadyClaimed:true,league:league.name});
   if(/constraint|UNIQUE|revision/i.test(String(e)))return json({error:'Save conflict, retry'},409);
   throw e;
  }
  return json({claimed:true,league:league.name,reward:league.reward,revision:account.revision+1,
   save:updated});
 }catch(e){return failure(e)}
}

import {context,json,failure} from './_lib/pvp.js';
import {clanRead,clanMutate,clanFailure} from './_lib/clans.js';
export async function onRequestGet({request,env}){
 try {
  if(!env.DB)return json({error:'CLAN_UNAVAILABLE'},503);
  const uid=new URL(request.url).searchParams.get('me')==='1'?(await context(request,env)).uid:null;
  return await clanRead(request,env.DB,uid);
 }catch(error){return clanFailure(error)||failure(error);}
}
export async function onRequestPost({request,env}){
 try {
  const {uid}=await context(request,env);
  const raw=await request.text();if(raw.length>4096)return json({error:'CLAN_INVALID'},413);
  let body;try{body=JSON.parse(raw);}catch{return json({error:'CLAN_INVALID'},400);}
  return await clanMutate(env.DB,uid,body);
 }catch(error){return clanFailure(error)||failure(error);}
}

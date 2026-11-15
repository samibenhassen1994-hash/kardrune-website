import test from 'node:test';
import assert from 'node:assert/strict';
import {onRequestPut as saveDeck} from '../functions/api/pvp/deck.js';
import {onRequestPost as ticket} from '../functions/api/pvp/live-ticket.js';
import {OLYMPUS_HEROES,SKILL_VERSION} from '../shared/skill_catalog.js';
test('deck API saves Olympus and normal decks, issues tickets, rejects mismatched divine grants',async()=>{
 const key=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
 const jwk=await crypto.subtle.exportKey('jwk',key.publicKey),b64=x=>Buffer.from(x).toString('base64url'),now=Math.floor(Date.now()/1000);
 const raw=b64(JSON.stringify({alg:'RS256',kid:'deck-test'}))+'.'+b64(JSON.stringify({aud:'test',iss:'https://securetoken.google.com/test',sub:'tester',iat:now,exp:now+600}));
 const token=raw+'.'+b64(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key.privateKey,new TextEncoder().encode(raw)));
 const original=globalThis.fetch;globalThis.fetch=async()=>Response.json({keys:[{...jwk,kid:'deck-test',alg:'RS256'}]});
 try{
  for(const olympus of [false,true]){
   const ids=olympus?[...Object.keys(OLYMPUS_HEROES).map(h=>h+':3'),'sam:1','lira:1','dren:1']:['sam','lira','rhea','dren','tor','aria','kael','neris','nyra'].map(h=>h+':1');
   const save={owned:ids,attacks:Object.fromEntries(ids.map(id=>[id,60])),crits:Object.fromEntries(ids.map(id=>[id,8]))};
   const grants=ids.map(id=>({card_id:id,skill_id:OLYMPUS_HEROES[id.split(':')[0]]?.skillId??'C1',skill_version:SKILL_VERSION}));let writes=0;
   const env={FIREBASE_PROJECT_ID:'test',LIVE_PVP_URL:'wss://example.invalid',DB:{prepare:sql=>({bind:()=>({
    first:async()=>sql.includes('is_banned')?{is_banned:0}:sql.includes('JOIN')?{cards_json:JSON.stringify(ids),save_json:JSON.stringify(save)}:{save_json:JSON.stringify(save)},
    all:async()=>({results:sql.includes('skill_legacy_cards')?[]:grants}),run:async()=>{writes++;return {meta:{changes:1}};}
   })})}};
   const request=method=>new Request('https://example.invalid/api/pvp/deck',{method,headers:{authorization:'Bearer '+token},body:JSON.stringify({cards:ids,revision:1})});
   assert.equal((await saveDeck({request:request('PUT'),env})).status,200);
   assert.equal((await ticket({request:request('POST'),env})).status,200);assert.equal(writes,2);
   if(olympus){grants[0].skill_id='D2';assert.equal((await saveDeck({request:request('PUT'),env})).status,422);assert.equal((await ticket({request:request('POST'),env})).status,409);assert.equal(writes,2);}
  }
 }finally{globalThis.fetch=original;}
});

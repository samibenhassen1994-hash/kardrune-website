import {json} from './auth.js';
import {deckPower} from '../../../shared/deck_power.js';
const idPattern=/^[a-f0-9-]{32,36}$/;
const projection=`c.id,c.name,c.description,c.emblem,c.invite_code AS inviteCode,c.created_at AS createdAt,
 p.display_name AS founder,(SELECT COUNT(*) FROM idle_clan_members m WHERE m.clan_id=c.id) AS memberCount`;
const base=`SELECT ${projection} FROM idle_clans c JOIN players p ON p.uid=c.owner_uid`;
export function validateClan(body){
 const name=typeof body.name==='string'?body.name.normalize('NFKC').trim():'';
 const description=typeof body.description==='string'?body.description.trim():'';
 if((body.description!==undefined&&typeof body.description!=='string')||!name||[...name].length>24||[...description].length>160||/[<>\p{Cc}]/u.test(name+description)||!Number.isInteger(body.emblem)||body.emblem<0||body.emblem>4)
 throw new Error('CLAN_INVALID');
 return {name,nameKey:name.toLowerCase(),description,emblem:body.emblem};
}
export async function clanRead(request,db,uid=null){
 const q=new URL(request.url).searchParams;
 const offset=Number(q.get('offset')||0);
 if(!Number.isSafeInteger(offset)||offset<0||offset>100000)return json({error:'CLAN_INVALID'},400);
 if(q.get('me')==='1') {
  if(!uid)return json({error:'CLAN_LOGIN'},401);
  const row=await db.prepare(`${base} JOIN idle_clan_members mine ON mine.clan_id=c.id WHERE mine.uid=?`).bind(uid).first();
  const role=await db.prepare('SELECT role FROM player_roles WHERE uid=?').bind(uid).first();
  return json({clan:row||null,canDelete:role?.role==='admin'});
 }
 const code=q.get('invite'),id=q.get('id');
 if(code||id){
  if(!idPattern.test(code||id))return json({error:'CLAN_NOT_FOUND'},404);
  const clan=await db.prepare(`${base} WHERE c.${code?'invite_code':'id'}=?`).bind(code||id).first();
  if(!clan)return json({error:'CLAN_NOT_FOUND'},404);
  const members=await db.prepare(`SELECT p.display_name AS name,p.avatar,d.cards_json,s.save_json FROM idle_clan_members m JOIN players p ON p.uid=m.uid LEFT JOIN pvp_decks d ON d.uid=p.uid LEFT JOIN demo_saves s ON s.uid=p.uid WHERE m.clan_id=? ORDER BY m.joined_at,m.uid LIMIT 21 OFFSET ?`).bind(clan.id,offset).all();
  return json({clan,members:members.results.slice(0,20).map(row=>{let power=0;try{power=deckPower(JSON.parse(row.cards_json||'[]'),JSON.parse(row.save_json||'{}'));}catch{}return {name:row.name,avatar:row.avatar,power};}),hasMore:members.results.length>20});
 }
 const rows=await db.prepare(`${base} ORDER BY c.created_at,c.id LIMIT 21 OFFSET ?`).bind(offset).all();
 return json({clans:rows.results.slice(0,20),hasMore:rows.results.length>20});
}
export async function clanMutate(db,uid,body,now=Date.now()){
 if(!body||typeof body.requestId!=='string'||!idPattern.test(body.requestId)||!['create','join','leave','delete'].includes(body.action))return json({error:'CLAN_INVALID'},400);
 const data=body.action==='create'?validateClan(body):{};
 const clanId=body.action==='create'?body.requestId:body.clanId;
 if(typeof clanId!=='string'||!idPattern.test(clanId))return json({error:'CLAN_INVALID'},400);
 if(['leave','delete'].includes(body.action)&&body.confirm!==true)return json({error:'CLAN_CONFIRM'},400);
 if(body.action==='delete'){
  const role=await db.prepare('SELECT role FROM player_roles WHERE uid=?').bind(uid).first();
  if(role?.role!=='admin')return json({error:'CLAN_FORBIDDEN'},403);
 }
 const payload=JSON.stringify({action:body.action,clanId,...data});
 const old=await db.prepare('SELECT payload,clan_id FROM idle_clan_requests WHERE uid=? AND request_id=?').bind(uid,body.requestId).first();
 if(old){if(old.payload!==payload)return json({error:'CLAN_INVALID'},422);return json({ok:true,clanId:old.clan_id});}
 const pending=`EXISTS(SELECT 1 FROM idle_clan_requests WHERE uid=? AND request_id=? AND done=0)`;
 const statements=[db.prepare('INSERT INTO idle_clan_requests(uid,request_id,payload,clan_id,created_at) VALUES(?,?,?,?,?) ON CONFLICT DO NOTHING').bind(uid,body.requestId,payload,clanId,now)];
 if(body.action==='create') statements.push(db.prepare(`INSERT INTO idle_clans(id,name,name_key,description,emblem,owner_uid,invite_code,created_at) SELECT ?,?,?,?,?,?,?,? WHERE ${pending}`).bind(clanId,data.name,data.nameKey,data.description,data.emblem,uid,crypto.randomUUID(),now,uid,body.requestId));
 if(body.action==='join') statements.push(db.prepare(`INSERT INTO idle_clan_members(uid,clan_id,joined_at) SELECT ?,?,? WHERE ${pending} AND NOT EXISTS(SELECT 1 FROM idle_clan_members WHERE uid=? AND clan_id=?)`).bind(uid,clanId,now,uid,body.requestId,uid,clanId));
 if(body.action==='leave') statements.push(db.prepare(`DELETE FROM idle_clan_members WHERE uid=? AND clan_id=? AND ${pending}`).bind(uid,clanId,uid,body.requestId));
 if(body.action==='delete') statements.push(db.prepare(`DELETE FROM idle_clans WHERE id=? AND ${pending} AND EXISTS(SELECT 1 FROM player_roles WHERE uid=? AND role='admin')`).bind(clanId,uid,body.requestId,uid));
 statements.push(db.prepare('UPDATE idle_clan_requests SET done=1 WHERE uid=? AND request_id=?').bind(uid,body.requestId));
 await db.batch(statements);
 // Reject a concurrent reuse of a request id with different parameters.
 const receipt=await db.prepare('SELECT payload FROM idle_clan_requests WHERE uid=? AND request_id=?').bind(uid,body.requestId).first();
 if(receipt.payload!==payload)return json({error:'CLAN_INVALID'},422);
 return json({ok:true,clanId});
}
export function clanFailure(error){
 const message=String(error?.message||error);
 if(/no such table|no such column/.test(message))return json({error:'CLAN_UNAVAILABLE'},503);
 if(message.includes('CLAN_CREATE_LIMIT'))return json({error:'CLAN_CREATE_LIMIT'},429);
 if(message.includes('name_key'))return json({error:'CLAN_NAME_TAKEN'},422);
 if(/CLAN_ALREADY_MEMBER|idle_clan_members.uid/.test(message))return json({error:'CLAN_ALREADY_MEMBER'},422);
 if(/FOREIGN KEY/.test(message))return json({error:'CLAN_NOT_FOUND'},422);
 if(/CLAN_INVALID/.test(message))return json({error:'CLAN_INVALID'},400);
 return null;
}

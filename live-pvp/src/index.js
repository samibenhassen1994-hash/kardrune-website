import {buildHand,resolveDuelFromStarter,pickWinner,rollInitiative,starterForRound} from './rules.js';
import {validSkillForStage,SKILL_BY_ID,SKILL_VERSION} from '../../shared/skill_catalog.js';
import {effectiveCardStats} from '../../shared/card_stat_limits.js';
const CHOOSE_MS=30000;
const MAX_ROUNDS=3;
const WINS_TO_WIN=2;
const PONG_GRACE_MS=18000;
const send=(ws,obj)=>{try{if(ws.readyState===1)ws.send(JSON.stringify(obj))}catch{}};
const secureRandom=()=>crypto.getRandomValues(new Uint32Array(1))[0]/0x100000000;
export default {
 async fetch(request,env){
  const url=new URL(request.url);
  if(url.pathname!=='/connect'||request.headers.get('Upgrade')?.toLowerCase()!=='websocket')
   return new Response('WebSocket required',{status:426});
  const origin=request.headers.get('Origin')||'';
  if(!['https://kardrune.com','https://www.kardrune.com'].includes(origin))return new Response('Forbidden origin',{status:403});
  const ticket=url.searchParams.get('ticket');
  if(!ticket||!/^[0-9a-f-]{36}$/i.test(ticket))return new Response('Invalid ticket',{status:401});
  const row=await env.DB.prepare('SELECT uid FROM pvp_live_tickets WHERE ticket=? AND expires_at>?').bind(ticket,Date.now()).first();
  if(!row)return new Response('Ticket expired',{status:401});
  const result=await env.DB.prepare('DELETE FROM pvp_live_tickets WHERE uid=? AND ticket=? AND expires_at>?').bind(row.uid,ticket,Date.now()).run();
  if(result.meta?.changes!==1)return new Response('Ticket already used',{status:401});
  const deckRow=await env.DB.prepare('SELECT d.cards_json,s.save_json,p.display_name FROM pvp_decks d JOIN demo_saves s ON d.uid=s.uid JOIN players p ON p.uid=d.uid WHERE d.uid=? AND p.is_banned=0').bind(row.uid).first();
  if(!deckRow)return new Response('Deck unavailable',{status:403});
  const save=JSON.parse(deckRow.save_json),ids=JSON.parse(deckRow.cards_json);
  if(!Array.isArray(ids)||ids.length<MAX_ROUNDS||ids.length>9||new Set(ids).size!==ids.length)return new Response('Invalid deck',{status:400});
  const deck=[];
  for(const id of ids){
   const [hero,stageText]=id.split(':'),stage=Number(stageText);
   const grant=await env.DB.prepare('SELECT attack,crit,skill_id,skill_version FROM skill_grants WHERE uid=? AND card_id=?').bind(row.uid,id).first();
   const attack=grant?.attack,crit=grant?.crit,skillId=grant?.skill_id;
   if(!save.owned?.includes(id)||!['sam','lira','rhea','dren','tor','aria','kael','neris','nyra'].includes(hero)||![1,2,3].includes(stage)||!Number.isInteger(attack)||attack<1||attack>100||!Number.isInteger(crit)||crit<0||crit>25)
    return new Response('Invalid card',{status:400});
   if(grant.skill_version!==SKILL_VERSION||!validSkillForStage(skillId,stage))return new Response('Skill grant unavailable',{status:409});
   const effective=effectiveCardStats(stage,attack,crit);
   deck.push({id,hero,stage,...effective,skillId,skillRarity:SKILL_BY_ID[skillId].rarity,skillVersion:SKILL_VERSION});
  }
  const id=env.LOBBY.idFromName('friendly-global-v1');
  const avatar=['player','guard','vassal','king'].includes(save.avatar)?save.avatar:'player';
  return env.LOBBY.get(id).fetch('https://lobby/connect',{headers:{Upgrade:'websocket','X-Player':row.uid,'X-Name':deckRow.display_name,'X-Avatar':avatar,'X-Deck':JSON.stringify(deck)}});
 }
};
export class PvpLobby {
 constructor(state,env){
  this.state=state;this.env=env;this.waiting=null;this.matches=new Map();this.sockets=new Map();
  this.heartbeat=setInterval(()=>this.checkConnections(),5000);
 }
 async fetch(request){
  if(request.headers.get('Upgrade')?.toLowerCase()!=='websocket')return new Response('WebSocket required',{status:426});
  const uid=request.headers.get('X-Player'),name=request.headers.get('X-Name'),avatar=request.headers.get('X-Avatar')||'player',deck=JSON.parse(request.headers.get('X-Deck')||'[]');
  if(!uid||deck.length<MAX_ROUNDS||deck.length>9)return new Response('Invalid match participant',{status:400});
  const pair=new WebSocketPair(),client=pair[0],server=pair[1];server.accept();
  const previous=this.sockets.get(uid);
  if(previous){this.drop(previous);try{previous.ws.close(4000,'Reconnected')}catch{}}
  for(let i=deck.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[deck[i],deck[j]]=[deck[j],deck[i]]}
  const player={uid,name,avatar,deck,ws:server,used:[],chosen:null,match:null,lastSeen:Date.now()};
  this.sockets.set(uid,player);
  server.addEventListener('message',event=>{
   if(this.sockets.get(uid)!==player)return;
   player.lastSeen=Date.now();
   try{
    if(typeof event.data!=='string'||event.data.length>500)return;
    const data=JSON.parse(event.data);
    if(data?.type==='play'&&typeof data.id==='string')this.play(player,data.id);
    else if(data?.type==='ready')this.ready(player);
    else if(data?.type==='pong'){} // Heartbeat acknowledgement.
   }catch{send(server,{type:'error',message:'Invalid action'})}
  });
  server.addEventListener('close',()=>this.drop(player));
  server.addEventListener('error',()=>this.drop(player));
  const waiting=this.waiting;this.waiting=null;
  if(waiting&&waiting.uid!==uid&&this.sockets.get(waiting.uid)===waiting){
   const initiative=rollInitiative(secureRandom);
   const match={id:crypto.randomUUID(),players:[waiting,player],round:0,scores:[0,0],selectTimer:null,readyTimer:null,awaiting:null,initiative};
   waiting.match=match;player.match=match;this.matches.set(match.id,match);
   send(waiting.ws,{type:'dice',rolls:initiative.rolls,attempts:initiative.attempts,
    starter:initiative.starter,matchId:match.id});
   send(player.ws,{type:'dice',rolls:[...initiative.rolls].reverse(),
    attempts:initiative.attempts.map(rolls=>[...rolls].reverse()),
    starter:1-initiative.starter,matchId:match.id});
   this.next(match);
  }else{this.waiting=player;send(server,{type:'waiting'})}
  return new Response(null,{status:101,webSocket:client});
 }
 checkConnections(){
  const now=Date.now();
  for(const player of this.sockets.values()){
   if(now-player.lastSeen>PONG_GRACE_MS){
    this.drop(player);try{player.ws.close(4001,'Connection lost')}catch{}
   }else send(player.ws,{type:'ping'});
  }
 }
 clearTimers(match){clearTimeout(match.selectTimer);clearTimeout(match.readyTimer);match.selectTimer=null;match.readyTimer=null}
 drop(player){
  if(this.sockets.get(player.uid)!==player)return;
  this.sockets.delete(player.uid);
  if(this.waiting===player)this.waiting=null;
  const match=player.match;if(!match||!this.matches.has(match.id))return;
  this.finish(match,'opponent_disconnected',player.uid);
 }
 next(match){
  if(!this.matches.has(match.id))return;
  this.clearTimers(match);
  // Best-of-three: finish as soon as someone has two round wins.
  // A third round is the maximum, including when one ends in a draw.
  if(match.scores.some(s=>s>=WINS_TO_WIN)||match.round>=MAX_ROUNDS){
   this.finish(match,'completed');return;
  }
  const [a,b]=match.players;
  const handA=buildHand(a.deck,a.used),handB=buildHand(b.deck,b.used);
  if(!handA.length||!handB.length){this.finish(match,'completed');return}
  match.awaiting=null;match.round++;a.chosen=null;b.chosen=null;
  const deadline=Date.now()+CHOOSE_MS;
  send(a.ws,{type:'hand',round:match.round,playerName:a.name,playerAvatar:a.avatar,opponent:b.name,opponentAvatar:b.avatar,score:match.scores,hand:handA,deckSize:a.deck.length,usedCount:a.used.length,durationMs:CHOOSE_MS,deadline,matchId:match.id});
  send(b.ws,{type:'hand',round:match.round,playerName:b.name,playerAvatar:b.avatar,opponent:a.name,opponentAvatar:a.avatar,score:[...match.scores].reverse(),hand:handB,deckSize:b.deck.length,usedCount:b.used.length,durationMs:CHOOSE_MS,deadline,matchId:match.id});
  match.selectTimer=setTimeout(()=>{
   if(!this.matches.has(match.id)||match.awaiting)return;
   for(const p of match.players){
    if(p.chosen)continue;
    const options=buildHand(p.deck,p.used);
    if(options.length)this.play(p,options[Math.floor(Math.random()*options.length)].id,true);
   }
  },CHOOSE_MS);
 }
 play(player,id,automatic=false){
  const match=player.match;
  if(!match||!this.matches.has(match.id)||match.awaiting||player.chosen)return;
  const card=buildHand(player.deck,player.used).find(c=>c.id===id);
  if(!card){send(player.ws,{type:'error',message:'Card not in your hand'});return}
  player.chosen=card;
  send(player.ws,{type:'locked',card:id,automatic});
  const other=match.players.find(p=>p!==player);
  send(other.ws,{type:'opponent_locked'});
  if(!match.players.every(p=>p.chosen))return;
  this.clearTimers(match);
  const [a,b]=match.players;
  a.used.push(a.chosen.id);b.used.push(b.chosen.id);
  const roundStarter=starterForRound(match.initiative?.starter??0,match.round);
  const result=resolveDuelFromStarter(a.chosen,b.chosen,roundStarter);
  const timeline=result.log.map(entry=>({...entry,round:match.round,matchId:match.id}));
  if(result.winner===0)match.scores[0]++;
  if(result.winner===1)match.scores[1]++;
  const event={type:'round_result',round:match.round,cards:[a.chosen,b.chosen],winner:result.winner,
   log:timeline,startHp:result.startHp,finalHp:result.hp,maxHp:result.maxHp,
   score:match.scores,selfIndex:0,starter:roundStarter};
  match.awaiting=new Set([a.uid,b.uid]);
  send(a.ws,event);
  send(b.ws,{...event,cards:[b.chosen,a.chosen],winner:result.winner==='draw'?'draw':1-result.winner,
   selfIndex:1,starter:1-roundStarter,score:[...match.scores].reverse()});
  match.readyTimer=setTimeout(()=>{if(!this.matches.has(match.id)||!match.awaiting)return;
   const late=[...match.awaiting];this.finish(match,'replay_timeout',late.length===1?late[0]:null)
  },180000);
  a.chosen=null;b.chosen=null;
 }
 ready(player){
  const match=player.match;
  if(!match||!this.matches.has(match.id)||!match.awaiting)return;
  match.awaiting.delete(player.uid);
  if(match.awaiting.size===0)this.next(match);
 }
 finish(match,reason,leaverUid=null){
  if(!this.matches.has(match.id))return;
  this.clearTimers(match);this.matches.delete(match.id);
  const winner=leaverUid?match.players.find(p=>p.uid!==leaverUid)?.uid:null;
  const winning=winner||(reason==='completed'&&pickWinner(match.scores)!=='draw'?match.players[pickWinner(match.scores)].uid:null);
  const [a,b]=match.players;
  const job=this.persistResult(match,a,b,winning,reason).then(persisted=>{
   match.players.forEach((p,i)=>{
    p.match=null;p.chosen=null;
    if(this.sockets.get(p.uid)!==p)return;
    send(p.ws,{type:'finished',reason,winner:winning===null?'draw':winning===p.uid?'you':'opponent',
     reward:persisted&&reason==='completed'&&winning===p.uid?100:0,
     score:i===0?match.scores:[...match.scores].reverse()});
   });
  });
  if(typeof this.state.waitUntil==='function')this.state.waitUntil(job);
  return job;
 }
 async persistResult(match,a,b,winning,reason){
  for(let attempt=0;attempt<4;attempt++){
   try{
    await this.env.DB.prepare('INSERT INTO pvp_live_history(id,player_a,player_b,score_a,score_b,winner_uid,completed_at,reason) VALUES(?,?,?,?,?,?,?,?)')
     .bind(match.id,a.uid,b.uid,match.scores[0],match.scores[1],winning,Date.now(),reason).run();
    return true;
   }catch(error){
    if(attempt===3){console.error('Unable to persist PvP result',match.id,error);return false}
    await new Promise(resolve=>setTimeout(resolve,100*(attempt+1)));
   }
  }
  return false;
 }
}

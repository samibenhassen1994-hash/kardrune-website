import {buildHand,resolveDuelFromStarter,pickWinner,rollInitiative,starterForRound} from './rules.js';
import {validSkillForCard,SKILL_BY_ID,SKILL_VERSION,OLYMPUS_HEROES} from '../../shared/skill_catalog.js';
import {effectiveCardStats} from '../../shared/card_stat_limits.js';
import {allocateBotName,botWaitMs,generateBotDeck,chooseBotCard} from './bot_policy.js';
import {botResultsReady} from '../../functions/api/_lib/bot_results.js';
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
  if(!Array.isArray(ids)||ids.length!==9||new Set(ids).size!==ids.length)return new Response('Invalid deck',{status:400});
  const deck=[];
  for(const id of ids){
   const [hero,stageText]=id.split(':'),stage=Number(stageText);
   const grant=await env.DB.prepare('SELECT attack,crit,skill_id,skill_version FROM skill_grants WHERE uid=? AND card_id=?').bind(row.uid,id).first();
   const attack=grant?.attack,crit=grant?.crit,skillId=grant?.skill_id;
   if(!save.owned?.includes(id)||!['sam','lira','rhea','dren','tor','aria','kael','neris','nyra','zeus','poseidon','hades','athena','ares','apollo'].includes(hero)||![1,2,3].includes(stage)||!Number.isInteger(attack)||attack<1||attack>100||!Number.isInteger(crit)||crit<0||crit>25)
    return new Response('Invalid card',{status:400});
   if(grant.skill_version!==SKILL_VERSION||!validSkillForCard(id,skillId,stage))return new Response('Skill grant unavailable',{status:409});
   if(OLYMPUS_HEROES[hero]&&(stage!==3||attack!==100||crit!==25))return new Response('Invalid divine card',{status:400});
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
  if(!uid||deck.length!==9)return new Response('Invalid match participant',{status:400});
  // The Durable Object serializes requests to this lobby. Reject a second
  // session before creating a socket or touching the active match.
  if(this.sockets.has(uid)){
   const pair=new WebSocketPair(),client=pair[0],server=pair[1];server.accept();
   send(server,{type:'error',code:'account_session_active'});
   server.close(4009,'Account session active');
   return new Response(null,{status:101,webSocket:client});
  }
  const pair=new WebSocketPair(),client=pair[0],server=pair[1];server.accept();
  for(let i=deck.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[deck[i],deck[j]]=[deck[j],deck[i]]}
  const player={uid,name,avatar,deck,ws:server,used:[],chosen:null,nextBlessing:null,match:null,lastSeen:Date.now()};
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
   this.startMatch(waiting,player);
  }else{this.waiting=player;send(server,{type:'waiting'});
   // Enable only after the bot history/ranking migration is installed.
   if(this.env.PVP_BOTS_ENABLED==='true')player.botTimer=setTimeout(()=>{
    const job=this.matchBot(player);this.state.waitUntil?.(job);
   },botWaitMs(secureRandom));
  }
  return new Response(null,{status:101,webSocket:client});
 }
 startMatch(waiting,player){
   clearTimeout(waiting.botTimer);clearTimeout(player.botTimer);
   waiting.used=[];player.used=[];
   const initiative=rollInitiative(secureRandom);
   const match={id:crypto.randomUUID(),players:[waiting,player],round:0,scores:[0,0],selectTimer:null,readyTimer:null,awaiting:null,initiative,initializing:true};
   waiting.match=match;player.match=match;this.matches.set(match.id,match);
   const launch=()=>{
   if(!this.matches.has(match.id))return;
   match.initializing=false;
   send(waiting.ws,{type:'dice',rolls:initiative.rolls,attempts:initiative.attempts,
    starter:initiative.starter,matchId:match.id});
   send(player.ws,{type:'dice',rolls:[...initiative.rolls].reverse(),
    attempts:initiative.attempts.map(rolls=>[...rolls].reverse()),
    starter:1-initiative.starter,matchId:match.id});
   this.next(match);
   };
   // Reserve both sessions synchronously, then snapshot starting leagues.
   // Old databases keep the original path; migration enables only snapshots,
   // not bot matchmaking (which additionally requires the explicit flag).
   const job=(async()=>{
    if(await botResultsReady(this.env.DB)){
     await this.env.DB.batch(match.players.filter(p=>!p.isBot).map(p=>this.env.DB.prepare(
      'INSERT INTO pvp_match_starts(match_id,uid,points) SELECT ?,?,COALESCE((SELECT points FROM pvp_rankings WHERE uid=?),0)'
     ).bind(match.id,p.uid,p.uid)));
    }
    launch();
   })().catch(error=>{console.error('Match initialization failed',error);this.finish(match,'initialization_failed');});
   this.state.waitUntil?.(job);
   return job;
 }
 async matchBot(player){
  const eligible=()=>this.waiting===player&&!player.match&&this.sockets.get(player.uid)===player;
  if(!eligible())return;
  try{
   // Fail closed until the bot result writer and schema are installed.
   const schema=await this.env.DB.prepare("SELECT value FROM pvp_ranked_meta WHERE key='bot_results_v1'").first();
   if(schema?.value!=='ready')return;
   const rank=await this.env.DB.prepare('SELECT points FROM pvp_rankings WHERE uid=?').bind(player.uid).first();
   const name=await allocateBotName(this.state.storage,player.uid);
   // Storage awaits allow real matchmaking/cancellation to run first.
   if(!eligible())return;
   const points=Number(rank?.points)||0;
   const bot={uid:`virtual:${crypto.randomUUID()}`,isBot:true,name,
    avatar:['player','guard','vassal','king'][Math.floor(secureRandom()*4)],
    deck:generateBotDeck(points,secureRandom),points,
    style:['aggressive','defensive','strategic'][Math.floor(secureRandom()*3)],
    used:[],chosen:null,nextBlessing:null,match:null};
   player.startPoints=points;
   this.waiting=null;await this.startMatch(player,bot);
  }catch(error){console.error('Bot matchmaking unavailable',error);}
 }
 checkConnections(){
  const now=Date.now();
  for(const player of this.sockets.values()){
   if(now-player.lastSeen>PONG_GRACE_MS){
    this.drop(player);try{player.ws.close(4001,'Connection lost')}catch{}
   }else send(player.ws,{type:'ping'});
  }
 }
 clearTimers(match){clearTimeout(match.selectTimer);clearTimeout(match.readyTimer);clearTimeout(match.botTimer);match.selectTimer=null;match.readyTimer=null;match.botTimer=null}
 drop(player){
  if(this.sockets.get(player.uid)!==player)return;
  this.sockets.delete(player.uid);
  clearTimeout(player.botTimer);
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
  send(a.ws,{type:'hand',round:match.round,playerName:a.name,playerAvatar:a.avatar,opponent:b.name,opponentAvatar:b.avatar,score:match.scores,hand:handA,deckSize:a.deck.length,usedCount:a.used.length,nextBlessing:a.nextBlessing??null,durationMs:CHOOSE_MS,deadline,matchId:match.id});
  send(b.ws,{type:'hand',round:match.round,playerName:b.name,playerAvatar:b.avatar,opponent:a.name,opponentAvatar:a.avatar,score:[...match.scores].reverse(),hand:handB,deckSize:b.deck.length,usedCount:b.used.length,nextBlessing:b.nextBlessing??null,durationMs:CHOOSE_MS,deadline,matchId:match.id});
  match.selectTimer=setTimeout(()=>{
   if(!this.matches.has(match.id)||match.awaiting)return;
   for(const p of match.players){
    if(p.chosen)continue;
    const options=buildHand(p.deck,p.used);
    if(options.length)this.play(p,options[Math.floor(Math.random()*options.length)].id,true);
   }
  },CHOOSE_MS);
  const bot=match.players.find(p=>p.isBot);
  if(bot){
   const index=match.players.indexOf(bot),hand=buildHand(bot.deck,bot.used);
   const id=chooseBotCard({hand,remaining:bot.deck.filter(c=>!bot.used.includes(c.id)),
    points:bot.points,style:bot.style,score:[match.scores[index],match.scores[1-index]]},secureRandom);
   match.botTimer=setTimeout(()=>this.play(bot,id),Math.floor(secureRandom()*15001));
  }
 }
 play(player,id,automatic=false){
  const match=player.match;
  if(!match||match.initializing||!this.matches.has(match.id)||match.awaiting||player.chosen)return;
  const card=buildHand(player.deck,player.used).find(c=>c.id===id);
  if(!card){send(player.ws,{type:'error',message:'Card not in your hand'});return}
  player.chosen=card;
  send(player.ws,{type:'locked',card:id,automatic});
  const other=match.players.find(p=>p!==player);
  send(other.ws,{type:'opponent_locked'});
  if(!match.players.every(p=>p.chosen))return;
  this.clearTimers(match);
  const [a,b]=match.players;
  for(const p of [a,b])p.used.push(...buildHand(p.deck,p.used).map(c=>c.id));
  const roundStarter=starterForRound(match.initiative?.starter??0,match.round);
  const blessings=[a.nextBlessing??null,b.nextBlessing??null];
   a.nextBlessing=null;b.nextBlessing=null;
   const result=resolveDuelFromStarter(a.chosen,b.chosen,roundStarter,undefined,blessings);
   for(const player of [a,b]){
    const divine=OLYMPUS_HEROES[player.chosen?.hero];
    if(divine&&player.chosen.skillId===divine.skillId)player.nextBlessing={skillId:divine.skillId,...divine.blessing};
   }
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
  for(const p of match.players)if(p.isBot)this.ready(p);
 }
 ready(player){
  const match=player.match;
  if(!match||!this.matches.has(match.id)||!match.awaiting)return;
  match.awaiting.delete(player.uid);
  if(match.awaiting.size===0)this.next(match);
 }
 finish(match,reason,leaverUid=null){
  if(!this.matches.has(match.id))return;
  if(match.initializing){reason='initialization_cancelled';leaverUid=null;}
  this.clearTimers(match);this.matches.delete(match.id);
  const winner=leaverUid?match.players.find(p=>p.uid!==leaverUid)?.uid:null;
  const winning=winner||(reason==='completed'&&pickWinner(match.scores)!=='draw'?match.players[pickWinner(match.scores)].uid:null);
  const [a,b]=match.players;
  const job=this.persistResult(match,a,b,winning,reason).then(persisted=>{
   match.players.forEach((p,i)=>{
    p.match=null;p.chosen=null;
    if(this.sockets.get(p.uid)!==p)return;
    send(p.ws,{type:'finished',reason,winner:winning===null?'draw':winning===p.uid?'you':'opponent',
     reward:persisted&&['completed','opponent_disconnected','replay_timeout'].includes(reason)&&winning===p.uid?100:0,
     score:i===0?match.scores:[...match.scores].reverse()});
   });
  });
  if(typeof this.state.waitUntil==='function')this.state.waitUntil(job);
  return job;
 }
 async persistResult(match,a,b,winning,reason){
  for(let attempt=0;attempt<4;attempt++){
   try{
    if(a.isBot||b.isBot){
     const human=a.isBot?b:a,bot=a.isBot?a:b,index=match.players.indexOf(human);
     const forfeited=['opponent_disconnected','replay_timeout'].includes(reason)&&winning===bot.uid&&!match.initializing;
     const outcome=forfeited?'loss':reason!=='completed'?'void':winning===null?'draw':winning===human.uid?'win':'loss';
     await this.env.DB.prepare(`INSERT INTO pvp_bot_history
      (id,uid,bot_id,bot_name,player_score,bot_score,outcome,reason,start_points,completed_at)
      VALUES(?,?,?,?,?,?,?,?,COALESCE((SELECT points FROM pvp_match_starts WHERE match_id=? AND uid=?),?),?) ON CONFLICT(id) DO NOTHING`)
      .bind(match.id,human.uid,bot.uid,bot.name,match.scores[index],match.scores[1-index],outcome,reason,match.id,human.uid,human.startPoints,Date.now()).run();
     return true;
    }
    await this.env.DB.prepare('INSERT INTO pvp_live_history(id,player_a,player_b,score_a,score_b,winner_uid,completed_at,reason) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO NOTHING')
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

import {buildHand,resolveDuel,pickWinner} from './rules.js';
const send=(ws,obj)=>{try{ws.send(JSON.stringify(obj))}catch{}};
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
  if(!Array.isArray(ids)||ids.length<1||ids.length>9||new Set(ids).size!==ids.length)return new Response('Invalid deck',{status:400});
  const deck=[];
  for(const id of ids){
   const [hero,stageText]=id.split(':'),stage=Number(stageText),attack=save.attacks?.[id],crit=save.crits?.[id];
   if(!save.owned?.includes(id)||!['sam','lira','rhea','dren','tor','aria','kael','neris','nyra'].includes(hero)||![1,2,3].includes(stage)||!Number.isInteger(attack)||attack<1||attack>100||!Number.isInteger(crit)||crit<0||crit>25)return new Response('Invalid card', {status:400});
   deck.push({id,hero,stage,attack,crit});
  }
  const id=env.LOBBY.idFromName('friendly-global-v1');
  return env.LOBBY.get(id).fetch('https://lobby/connect',{headers:{Upgrade:'websocket','X-Player':row.uid,'X-Name':deckRow.display_name,'X-Deck':JSON.stringify(deck)}});
 }
};
export class PvpLobby {
 constructor(state,env){this.env=env;this.waiting=null;this.matches=new Map();this.sockets=new Map()}
 async fetch(request){
  if(request.headers.get('Upgrade')!=='websocket')return new Response('WebSocket required',{status:426});
  const uid=request.headers.get('X-Player'),name=request.headers.get('X-Name'),deck=JSON.parse(request.headers.get('X-Deck')||'[]');
  const pair=new WebSocketPair(),client=pair[0],server=pair[1];
  server.accept();
  const old=this.sockets.get(uid);if(old){try{old.ws.close(4000,'Reconnected')}catch{};this.drop(old)}
  const player={uid,name,deck,ws:server,used:[],chosen:null,match:null};
  this.sockets.set(uid,player);
  server.addEventListener('message',event=>{
   try{
    const data=JSON.parse(event.data);
    if(data?.type==='play'&&typeof data.id==='string')this.play(player,data.id);
   }catch{send(server,{type:'error',message:'Invalid action'})}
  });
  server.addEventListener('close',()=>this.drop(player));
  server.addEventListener('error',()=>this.drop(player));
  const waiting=this.waiting;this.waiting=null;
  if(waiting&&waiting.uid!==uid&&this.sockets.get(waiting.uid)===waiting){
   const match={id:crypto.randomUUID(),players:[waiting,player],round:0,scores:[0,0]};
   waiting.match=match;player.match=match;this.matches.set(match.id,match);
   this.next(match);
  }else{
   this.waiting=player;send(server,{type:'waiting'});
  }
  return new Response(null,{status:101,webSocket:client});
 }
 drop(player){
  if(this.sockets.get(player.uid)!==player)return;
  this.sockets.delete(player.uid);
  if(this.waiting===player)this.waiting=null;
  if(player.match){
   const match=player.match;this.matches.delete(match.id);
   const other=match.players.find(p=>p!==player);
   if(other&&this.sockets.get(other.uid)===other){
    other.match=null;other.chosen=null;other.used=[];
    send(other.ws,{type:'opponent_left'});
    this.waiting=other;
   }
  }
 }
 next(match){
  const [a,b]=match.players;
  const handA=buildHand(a.deck,a.used),handB=buildHand(b.deck,b.used);
  if(!handA.length||!handB.length){this.end(match);return}
  match.round++;a.chosen=null;b.chosen=null;
  send(a.ws,{type:'hand',round:match.round,opponent:b.name,score:match.scores,hand:handA});
  send(b.ws,{type:'hand',round:match.round,opponent:a.name,score:[...match.scores].reverse(),hand:handB});
 }
 play(player,id){
  const match=player.match;if(!match||player.chosen)return;
  const options=buildHand(player.deck,player.used);
  const card=options.find(c=>c.id===id);if(!card){send(player.ws,{type:'error',message:'Card not in your hand'});return}
  player.chosen=card;
  send(player.ws,{type:'locked',card:id});
  const [a,b]=match.players;
  if(!a.chosen||!b.chosen)return;
  a.used.push(a.chosen.id);b.used.push(b.chosen.id);
  const result=resolveDuel(a.chosen,b.chosen);
  if(result.winner===0)match.scores[0]++;
  if(result.winner===1)match.scores[1]++;
  const event={type:'round_result',round:match.round,cards:[a.chosen,b.chosen],winner:result.winner,log:result.log,score:match.scores};
  send(a.ws,event);
  send(b.ws,{...event,cards:[b.chosen,a.chosen],winner:result.winner==='draw'?'draw':1-result.winner,log:result.log.map(hit=>({...hit,actor:1-hit.actor})),score:[...match.scores].reverse()});
  // Client confirms animation completed before advancing, to allow full hit display.
  match.awaiting=new Set([a.uid,b.uid]);
  for(const p of [a,b])p.chosen=null;
 }
 end(match){
  if(!this.matches.has(match.id))return;
  this.matches.delete(match.id);
  const winner=pickWinner(match.scores);
  match.players.forEach((p,i)=>{p.match=null;send(p.ws,{type:'finished',winner:winner==='draw'?'draw':winner===i?'you':'opponent',score:i===0?match.scores:[...match.scores].reverse()})});
 }
}

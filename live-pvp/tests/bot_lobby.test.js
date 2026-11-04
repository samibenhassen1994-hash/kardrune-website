import test from 'node:test';
import assert from 'node:assert/strict';
import {PvpLobby} from '../src/index.js';
import {generateBotDeck} from '../src/bot_policy.js';
import {buildHand} from '../src/rules.js';

function setup(t,ready=true){
 t.mock.timers.enable({apis:['setTimeout','setInterval']});
 const writes=[],jobs=[],values=new Map();
 const db={prepare:sql=>{
  const stmt={first:async()=>sql.includes('sqlite_master')?{name:'pvp_ranked_meta'}:sql.includes('bot_results_v1')?{value:ready?'ready':'no'}:{points:250},
   run:async()=>{writes.push({sql,args:stmt.args});return {};},bind(...args){stmt.args=args;return stmt;}};return stmt;
 },batch:async stmts=>Promise.all(stmts.map(s=>s.run()))};
 const state={waitUntil:p=>jobs.push(p),storage:{transaction:async f=>f({get:async k=>values.get(k),put:async(k,v)=>values.set(k,v)})}};
 const lobby=new PvpLobby(state,{DB:db,PVP_BOTS_ENABLED:'true'});
 const human=uid=>({uid,name:uid,avatar:'player',deck:generateBotDeck(250,()=>.5),used:[],chosen:null,match:null,lastSeen:Date.now(),ws:{readyState:1,messages:[],send(s){this.messages.push(JSON.parse(s));}}});
 const a=human('a');lobby.sockets.set('a',a);lobby.waiting=a;
 t.after(()=>{clearInterval(lobby.heartbeat);for(const m of lobby.matches.values())lobby.clearTimers(m);});
 return {lobby,a,human,writes,jobs,values,setReady:v=>{ready=v;}};
}
test('complete bot match uses D20, skill replay, automatic readiness and persists exactly once',async t=>{
 const {lobby,a,writes,jobs}=setup(t);await lobby.matchBot(a);
 assert.equal(a.ws.messages[0].type,'dice');
 const match=a.match,bot=match.players[1];assert.ok(bot.isBot);
 for(let n=0;n<3&&lobby.matches.has(match.id);n++){
  // Real server preparation timer, bounded by 15 seconds.
  t.mock.timers.tick(15000);
  assert.ok(bot.chosen);
  lobby.play(a,buildHand(a.deck,a.used)[0].id);
  const replay=a.ws.messages.filter(m=>m.type==='round_result').at(-1);
  assert.ok(replay.log.length>0);assert.equal(match.awaiting.size,1);
  lobby.ready(a);
 }
 await Promise.all(jobs);
 assert.ok(a.ws.messages.some(m=>m.type==='finished'));
 const histories=writes.filter(w=>w.sql.includes('INSERT INTO pvp_bot_history'));
 assert.equal(histories.length,1);assert.equal(histories[0].args[1],'a');
 await lobby.finish(match,'completed');assert.equal(writes.filter(w=>w.sql.includes('INSERT INTO pvp_bot_history')).length,1);
});
test('human arrival during bot allocation wins race; cancelled queue never starts a bot',async t=>{
 const {lobby,a,human,writes}=setup(t);
 const pending=lobby.matchBot(a);const b=human('b');lobby.sockets.set('b',b);lobby.waiting=null;
 await lobby.startMatch(a,b);await pending;
 assert.equal(a.match.players[1],b);assert.equal(lobby.matches.size,1);
 assert.equal(writes.filter(w=>w.sql.includes('pvp_bot_history')).length,0);
 lobby.drop(a);await lobby.matchBot(a);assert.equal(lobby.matches.size,0);
});
test('two human participants complete D20, alternating rounds, replay acknowledgements and one result',async t=>{
 const {lobby,a,human,writes,jobs}=setup(t);
 const b=human('b');lobby.sockets.set('b',b);lobby.waiting=null;
 await lobby.startMatch(a,b);
 const match=a.match;
 const diceA=a.ws.messages.find(m=>m.type==='dice'),diceB=b.ws.messages.find(m=>m.type==='dice');
 assert.deepEqual(diceA.rolls,[...diceB.rolls].reverse());
 assert.equal(diceA.starter,1-diceB.starter);
 for(let n=0;n<3&&lobby.matches.has(match.id);n++){
  lobby.play(a,buildHand(a.deck,a.used)[0].id);
  lobby.play(b,buildHand(b.deck,b.used)[0].id);
  const replay=a.ws.messages.filter(m=>m.type==='round_result').at(-1);
  assert.equal(replay.starter,(diceA.starter+n)%2);
  assert.ok(replay.log.length>0);
  assert.equal(match.awaiting.size,2);lobby.ready(a);
  assert.equal(match.awaiting.size,1);lobby.ready(b);
 }
 await Promise.all(jobs);
 assert.equal(lobby.matches.size,0);
 assert.ok(match.round<=3);
 for(const p of [a,b])assert.equal(p.ws.messages.filter(m=>m.type==='finished').length,1);
 assert.equal(writes.filter(w=>w.sql.includes('INSERT INTO pvp_live_history')).length,1);
 assert.equal(writes.filter(w=>w.sql.includes('INSERT INTO pvp_bot_history')).length,0);
});
test('missing migration disables bot creation; disconnection clears bot timers and creates no reward',async t=>{
 const {lobby,a,writes,jobs,setReady}=setup(t,false);await lobby.matchBot(a);assert.equal(lobby.matches.size,0);
 setReady(true);
 await lobby.matchBot(a);lobby.drop(a);await Promise.all(jobs);
 t.mock.timers.tick(30000);
 const rows=writes.filter(w=>w.sql.includes('INSERT INTO pvp_bot_history'));
 assert.equal(rows.length,1);assert.equal(rows[0].args[6],'loss');
 assert.equal(lobby.matches.size,0);
});

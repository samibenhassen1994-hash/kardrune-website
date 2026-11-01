import test from 'node:test';
import assert from 'node:assert/strict';
import {PvpLobby} from '../src/index.js';

test('each hand identifies both players with their own profile avatars and score order',()=>{
 const lobby=new PvpLobby({},{});
 const messagesA=[],messagesB=[];
 const deck=Array.from({length:3},(_,i)=>({id:`sam:${i+1}`}));
 const a={uid:'a',name:'Sam',avatar:'guard',deck,used:[],chosen:null,
  ws:{readyState:1,send:value=>messagesA.push(JSON.parse(value))}};
 const b={uid:'b',name:'Rival',avatar:'king',deck,used:[],chosen:null,
  ws:{readyState:1,send:value=>messagesB.push(JSON.parse(value))}};
 const match={id:'m',players:[a,b],round:0,scores:[1,0],selectTimer:null,
  readyTimer:null,awaiting:null};
 lobby.matches.set(match.id,match);
 try{
  lobby.next(match);
  assert.deepEqual({name:messagesA[0].playerName,avatar:messagesA[0].playerAvatar,
   rival:messagesA[0].opponent,rivalAvatar:messagesA[0].opponentAvatar,
   score:messagesA[0].score},
   {name:'Sam',avatar:'guard',rival:'Rival',rivalAvatar:'king',score:[1,0]});
  assert.deepEqual({name:messagesB[0].playerName,avatar:messagesB[0].playerAvatar,
   rival:messagesB[0].opponent,rivalAvatar:messagesB[0].opponentAvatar,
   score:messagesB[0].score},
   {name:'Rival',avatar:'king',rival:'Sam',rivalAvatar:'guard',score:[0,1]});
 }finally{
  lobby.clearTimers(match);
  clearInterval(lobby.heartbeat);
 }
});
test('finished payload waits for durable history before advertising reward',async()=>{
 const messagesA=[],messagesB=[];
 const ws=messages=>({readyState:1,send:value=>messages.push(JSON.parse(value))});
 const a={uid:'a',ws:ws(messagesA),match:null,chosen:null};
 const b={uid:'b',ws:ws(messagesB),match:null,chosen:null};
 let persist;
 const persisted=new Promise(resolve=>{persist=resolve});
 const env={DB:{prepare:()=>({bind:()=>({run:()=>persisted})})}};
 const lobby=new PvpLobby({waitUntil:()=>{}},env);
 const match={id:'m',players:[a,b],round:2,scores:[2,0],selectTimer:null,
  readyTimer:null,awaiting:null};
 a.match=match;b.match=match;lobby.matches.set(match.id,match);
 lobby.sockets.set('a',a);lobby.sockets.set('b',b);
 try{
  const finished=lobby.finish(match,'completed');
  assert.equal(messagesA.length,0);
  persist();
  await finished;
  assert.equal(messagesA[0].reward,100);
  assert.equal(messagesB[0].reward,0);
 }finally{clearInterval(lobby.heartbeat)}
});

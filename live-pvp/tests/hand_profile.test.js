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

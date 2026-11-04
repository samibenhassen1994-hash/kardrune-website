import test from 'node:test';
import assert from 'node:assert/strict';
import {PvpLobby} from '../src/index.js';

class Socket {
  readyState=1;
  messages=[];
  listeners=new Map();
  accept(){}
  send(value){this.messages.push(JSON.parse(value))}
  addEventListener(type,handler){this.listeners.set(type,handler)}
  close(){this.readyState=3;this.listeners.get('close')?.()}
}

test('same UID is rejected while first search or match remains active',async()=>{
  const original=globalThis.WebSocketPair;
  const originalResponse=globalThis.Response;
  globalThis.WebSocketPair=class {constructor(){const client=new Socket(),server=new Socket();client.messages=server.messages;return {0:client,1:server}}};
  globalThis.Response=class {constructor(body,options){this.body=body;Object.assign(this,options)}};
  const writes=[];
  const db={prepare:sql=>({first:async()=>null,bind:(...args)=>({run:async()=>{writes.push({sql,args})}})})};
  const lobby=new PvpLobby({waitUntil:()=>{}},{DB:db});
  const deck=Array.from({length:3},(_,i)=>({id:`hero:${i}`,stage:1,attack:1,crit:0}));
  const join=uid=>lobby.fetch(new Request('https://lobby/connect',{headers:{Upgrade:'websocket','X-Player':uid,'X-Name':uid,'X-Deck':JSON.stringify(deck)}}));
  try{
    const first=await join('a');
    assert.equal(first.status,101);
    const duplicate=await join('a');
    assert.equal(duplicate.status,101);
    assert.equal(duplicate.webSocket.messages[0].code,'account_session_active');
    assert.equal(lobby.waiting.uid,'a');
    assert.equal(lobby.sockets.size,1);
    assert.equal(writes.length,0);
    const other=await join('b');
    assert.equal(other.status,101);
    assert.equal(lobby.matches.size,1);
    await join('a');
    assert.equal(lobby.matches.size,1);
    assert.equal(writes.length,0);
    lobby.sockets.get('a').ws.close();
    assert.equal(lobby.sockets.has('a'),false);
    assert.equal((await join('a')).status,101);
    assert.equal(lobby.sockets.has('a'),true);
    lobby.sockets.get('a').lastSeen = Date.now()-20000;
    lobby.checkConnections();
    assert.equal(lobby.sockets.has('a'),false);
    assert.equal((await join('a')).status,101);
    assert.equal(lobby.waiting.uid,'a');
    assert.equal(lobby.sockets.get('a').match,null);
  }finally{
    clearInterval(lobby.heartbeat);
    for(const match of lobby.matches.values())lobby.clearTimers(match);
    globalThis.WebSocketPair=original;
    globalThis.Response=originalResponse;
  }
});

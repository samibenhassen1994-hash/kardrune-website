import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
const source=readFileSync(new URL('../idle_flutter/web/boot-loading.js',import.meta.url),'utf8');
function boot(language='it') {
 const elements=new Map(['kr-loading','kr-loading-text','kr-retry'].map(id=>[id,{style:{},hidden:true,removed:false,remove(){this.removed=true;},addEventListener(type,fn){this[type]=fn;}}]));
 const events={},timers=new Map();let next=0,reloads=0;
 const window={addEventListener:(type,fn)=>events[type]=fn};
 runInNewContext(source,{window,document:{getElementById:id=>elements.get(id)},navigator:{language},localStorage:{getItem:()=>language},location:{reload:()=>reloads++},setTimeout:(fn,ms)=>{timers.set(++next,{fn,ms});return next;},clearTimeout:id=>timers.delete(id)});
 return {elements,events,timers,window,reloads:()=>reloads};
}
test('loading is localized and stays until first Flutter frame, then fades',()=>{
 for(const lang of ['en','it','es','ja','ko','zh','de']) {
  const b=boot(lang),root=b.elements.get('kr-loading');
  assert.ok(b.elements.get('kr-loading-text').textContent);
  assert.equal(root.removed,false);
  b.events['flutter-first-frame']();
  assert.equal(root.style.opacity,'0');
  assert.equal([...b.timers.values()].some(t=>t.ms===20000),false);
  [...b.timers.values()].find(t=>t.ms===220).fn();
  assert.equal(root.removed,true);
 }
});
test('slow or failed startup offers retry without exposing a blank game',()=>{
 const b=boot(),root=b.elements.get('kr-loading');
 [...b.timers.values()].find(t=>t.ms===20000).fn();
 assert.equal(root.removed,false);
 assert.equal(b.elements.get('kr-retry').hidden,false);
 b.elements.get('kr-retry').click();assert.equal(b.reloads(),1);
 b.events['flutter-first-frame']();assert.equal(root.style.opacity,'0');
 b.window.kardruneLoadingError();assert.equal(root.style.opacity,'0');
});
